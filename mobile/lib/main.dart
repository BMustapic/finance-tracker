import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Android emulator: use --dart-define=API_URL=http://10.0.2.2:8080
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
void main() => runApp(const FinanceApp());
String money(int cents) =>
    '${cents < 0 ? '-' : ''}€${(cents.abs() / 100).toStringAsFixed(2)}';
String dateText(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff24543e)),
      scaffoldBackgroundColor: const Color(0xfff7f8f5),
      useMaterial3: true,
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.client});
  final http.Client? client;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final http.Client client;
  Map<String, dynamic>? data;
  String? error;
  bool busy = false;
  int tab = 0;
  List<Map<String, dynamic>> rows(String key) => (data?[key] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  @override
  void initState() {
    super.initState();
    client = widget.client ?? http.Client();
    load();
  }

  @override
  void dispose() {
    if (widget.client == null) {
      client.close();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final response = await client
          .get(Uri.parse('$apiUrl/api/data'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Could not load finances');
      }
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          data = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Cannot reach the API. Check your connection and API_URL.',
        );
      }
    }
  }

  Future<bool> save(String path, Map<String, dynamic> body) async {
    setState(() => busy = true);
    try {
      final response = await client
          .post(
            Uri.parse('$apiUrl/api/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 201) {
        throw Exception((jsonDecode(response.body) as Map)['error']);
      }
      await load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unable to save: $e')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> addTransaction() async {
    final accounts = rows('accounts'), categories = rows('categories');
    if (accounts.isEmpty || categories.isEmpty) {
      return;
    }
    final description = TextEditingController(),
        amount = TextEditingController();
    var account = accounts.first['id'] as String,
        category = categories.first['id'] as String;
    var income = false;
    var date = DateTime.now();
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add transaction'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(income ? 'Income' : 'Expense'),
                    value: income,
                    onChanged: (v) => update(() => income = v),
                  ),
                  TextFormField(
                    controller: description,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a description'
                        : null,
                  ),
                  TextFormField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: 'Amount (€)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return n == null ||
                              !n.isFinite ||
                              n < .01 ||
                              n > 1000000000
                          ? 'Enter a positive amount'
                          : null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: account,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a['id'] as String,
                            child: Text(a['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => account = v!,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => category = v!,
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        update(() => date = selected);
                      }
                    },
                    child: Text(dateText(date)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, {
                    'description': description.text.trim(),
                    'amount':
                        (double.parse(amount.text.replaceAll(',', '.')) * 100)
                            .round() *
                        (income ? 1 : -1),
                    'accountId': account,
                    'categoryId': category,
                    'date': dateText(date),
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    description.dispose();
    amount.dispose();
    if (result != null && mounted) {
      await save('transactions', result);
    }
  }

  Future<void> addAccount() async {
    final name = TextEditingController(),
        opening = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add account'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Account name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: opening,
                decoration: const InputDecoration(
                  labelText: 'Opening balance (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return n == null || !n.isFinite || n.abs() > 1000000000
                      ? 'Enter a valid balance'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'opening':
                      (double.parse(opening.text.replaceAll(',', '.')) * 100)
                          .round(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    opening.dispose();
    if (result != null && mounted) {
      await save('accounts', result);
    }
  }

  Future<void> deleteTransaction(Map<String, dynamic> tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(tx['description'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      final r = await client
          .delete(Uri.parse('$apiUrl/api/transactions/${tx['id']}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 204) {
        throw Exception('Delete failed');
      }
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete transaction')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = rows('accounts'),
        transactions = rows(
          'transactions',
        )..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    final balance =
        accounts.fold<int>(0, (s, a) => s + (a['opening'] as int)) +
        transactions.fold<int>(0, (s, t) => s + (t['amount'] as int));
    final month = dateText(DateTime.now()).substring(0, 7),
        monthly = transactions.where(
          (t) => (t['date'] as String).startsWith(month),
        );
    final income = monthly
        .where((t) => (t['amount'] as int) > 0)
        .fold<int>(0, (s, t) => s + (t['amount'] as int));
    final expense = monthly
        .where((t) => (t['amount'] as int) < 0)
        .fold<int>(0, (s, t) => s - (t['amount'] as int));
    return Scaffold(
      appBar: AppBar(
        title: const Text('◈ pocket'),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!),
                ),
              ),
            if (data == null && error == null)
              const Center(child: CircularProgressIndicator()),
            if (data != null) ...[
              Text(
                tab == 0
                    ? 'Your money, at a glance.'
                    : tab == 1
                    ? 'Transactions'
                    : 'Your accounts',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              if (tab == 0) ...[
                Card(
                  color: const Color(0xff24543e),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL BALANCE',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          money(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Income this month\n${money(income)}'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Expenses this month\n${money(expense)}'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (tab != 2) ...[
                Text('Activity', style: Theme.of(context).textTheme.titleLarge),
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('A fresh start. Add your first transaction.'),
                  ),
                ...transactions.map(
                  (tx) => Card(
                    child: ListTile(
                      leading: Icon(
                        (tx['amount'] as int) > 0
                            ? Icons.south_west
                            : Icons.north_east,
                      ),
                      title: Text(tx['description'] as String),
                      subtitle: Text(
                        '${tx['date']} · ${rows('categories').firstWhere((c) => c['id'] == tx['categoryId'])['name']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(money(tx['amount'] as int)),
                          IconButton(
                            onPressed: busy
                                ? null
                                : () => deleteTransaction(tx),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete transaction',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (tab == 2) ...[
                ...accounts.map(
                  (a) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text(a['name'] as String),
                      subtitle: const Text('EUR · Personal account'),
                      trailing: Text(
                        money(
                          (a['opening'] as int) +
                              transactions
                                  .where((t) => t['accountId'] == a['id'])
                                  .fold<int>(
                                    0,
                                    (s, t) => s + (t['amount'] as int),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 90),
            ],
          ],
        ),
      ),
      floatingActionButton: data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: busy
                  ? null
                  : tab == 2
                  ? addAccount
                  : addTransaction,
              icon: const Icon(Icons.add),
              label: Text(tab == 2 ? 'Account' : 'Transaction'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }
}
