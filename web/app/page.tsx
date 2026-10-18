"use client";
import { useState, useEffect, FormEvent } from "react";
type Account = { id: string; name: string; opening: number };
type Tx = {
  id: string;
  accountId: string;
  categoryId: string;
  description: string;
  amount: number;
  date: string;
};
type Data = {
  accounts: Account[];
  categories: { id: string; name: string }[];
  transactions: Tx[];
};
const money = (n: number) =>
  new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" }).format(
    n / 100,
  );
const today = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
};
export default function Home() {
  const [data, setData] = useState<Data | null>(null),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [view, setView] = useState("Overview"),
    [query, setQuery] = useState("");
  async function load() {
    const r = await fetch("/api/data");
    if (!r.ok)
      throw Error("Could not load finances. Check that the API is running.");
    setData(await r.json());
  }
  useEffect(() => {
    load().catch((e) => setError(e.message));
  }, []);
  async function mutate(path: string, body?: unknown, method = "POST") {
    setBusy(true);
    setError("");
    try {
      const r = await fetch(`/api/${path}`, {
        method,
        headers: { "Content-Type": "application/json" },
        body: body ? JSON.stringify(body) : undefined,
      });
      if (!r.ok) {
        const e = await r.json();
        throw Error(e.error || "Unable to save");
      }
      await load();
      return true;
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unable to save");
      return false;
    } finally {
      setBusy(false);
    }
  }
  async function addTransaction(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget,
      f = new FormData(form);
    const cents = Math.round(Number(f.get("amount")) * 100);
    if (
      await mutate("transactions", {
        description: f.get("description"),
        amount: f.get("kind") === "expense" ? -cents : cents,
        accountId: f.get("accountId"),
        categoryId: f.get("categoryId"),
        date: f.get("date"),
      })
    )
      form.reset();
  }
  async function addAccount(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget,
      f = new FormData(form);
    if (
      await mutate("accounts", {
        name: f.get("name"),
        opening: Math.round(Number(f.get("opening")) * 100),
      })
    )
      form.reset();
  }
  const monthly =
    data?.transactions.filter((t) => t.date.startsWith(today().slice(0, 7))) ||
    [];
  const income = monthly.reduce((s, t) => s + Math.max(0, t.amount), 0),
    expense = monthly.reduce((s, t) => s + Math.max(0, -t.amount), 0);
  const balance =
    (data?.accounts.reduce((s, a) => s + a.opening, 0) || 0) +
    (data?.transactions.reduce((s, t) => s + t.amount, 0) || 0);
  const transactions = [...(data?.transactions || [])]
    .filter((t) => t.description.toLowerCase().includes(query.toLowerCase()))
    .sort((a, b) => b.date.localeCompare(a.date) || b.id.localeCompare(a.id));
  return (
    <div className="shell">
      <aside>
        <a className="brand" href="/">
          ◈ pocket
        </a>
        <div className="workspace">PERSONAL WORKSPACE</div>
        <nav>
          {["Overview", "Transactions", "Accounts"].map((name, i) => (
            <button
              key={name}
              className={view === name ? "active" : ""}
              onClick={() => setView(name)}
            >
              <span>{["▦", "⇄", "▣"][i]}</span>
              {name}
            </button>
          ))}
        </nav>
        <div className="aside-note">
          ● Local workspace
          <p>
            Your money.
            <br />A little more clarity.
          </p>
        </div>
      </aside>
      <main>
        <header>
          <span>
            My workspace <span className="slash">/</span> {view}
          </span>
          <div className="avatar">ME</div>
        </header>
        <div className="content">
          <div className="heading">
            <div>
              <p className="eyebrow">A CLEARER PICTURE</p>
              <h1>{view === "Overview" ? "Your money, at a glance." : view}</h1>
              <p className="sub">
                Small habits. Better decisions. More peace of mind.
              </p>
            </div>
            <span className="date">
              {new Date().toLocaleDateString("en-GB", {
                month: "long",
                year: "numeric",
              })}
            </span>
          </div>
          {error && (
            <div role="alert" className="error">
              {error}{" "}
              <button
                onClick={() =>
                  load()
                    .then(() => setError(""))
                    .catch((e) => setError(e.message))
                }
              >
                Retry
              </button>
            </div>
          )}
          {!data ? (
            <p>Loading your workspace…</p>
          ) : (
            <>
              {view !== "Accounts" && (
                <>
                  <section className="stats">
                    <article className="balance">
                      <span>Total balance ↗</span>
                      <h2>{money(balance)}</h2>
                      <small>Across {data.accounts.length} accounts</small>
                    </article>
                    <article>
                      <span>Income this month ↙</span>
                      <h2>{money(income)}</h2>
                      <small>Money coming in</small>
                    </article>
                    <article>
                      <span>Expenses this month ↗</span>
                      <h2>{money(expense)}</h2>
                      <small>Money going out</small>
                    </article>
                  </section>
                  <div className="grid">
                    <section className="panel">
                      <div className="panel-title">
                        <div>
                          <h3>
                            {view === "Transactions"
                              ? "All transactions"
                              : "Recent activity"}
                          </h3>
                          <p>The little things that add up.</p>
                        </div>
                        <span className="pill">
                          {data.transactions.length} transactions
                        </span>
                      </div>
                      <input
                        className="search"
                        aria-label="Search transactions"
                        placeholder="Search transactions…"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                      />
                      <div className="table-wrap">
                        <table>
                          <thead>
                            <tr>
                              <th>TRANSACTION</th>
                              <th>DATE</th>
                              <th>AMOUNT</th>
                              <th />
                            </tr>
                          </thead>
                          <tbody>
                            {transactions
                              .slice(0, view === "Transactions" ? undefined : 8)
                              .map((t) => (
                                <tr key={t.id}>
                                  <td>
                                    <div className="tx-name">
                                      <span className="tx-icon">
                                        {t.amount > 0 ? "↙" : "↗"}
                                      </span>
                                      <div>
                                        <strong>{t.description}</strong>
                                        <small>
                                          {
                                            data.categories.find(
                                              (c) => c.id === t.categoryId,
                                            )?.name
                                          }{" "}
                                          ·{" "}
                                          {
                                            data.accounts.find(
                                              (a) => a.id === t.accountId,
                                            )?.name
                                          }
                                        </small>
                                      </div>
                                    </div>
                                  </td>
                                  <td className="tx-date">{t.date}</td>
                                  <td
                                    className={
                                      t.amount > 0
                                        ? "amount positive"
                                        : "amount"
                                    }
                                  >
                                    {t.amount > 0 ? "+" : ""}
                                    {money(t.amount)}
                                  </td>
                                  <td>
                                    <button
                                      className="delete"
                                      aria-label={`Delete ${t.description}`}
                                      disabled={busy}
                                      onClick={() => {
                                        if (
                                          window.confirm(
                                            `Delete “${t.description}”?`,
                                          )
                                        )
                                          void mutate(
                                            `transactions/${t.id}`,
                                            undefined,
                                            "DELETE",
                                          );
                                      }}
                                    >
                                      ×
                                    </button>
                                  </td>
                                </tr>
                              ))}
                          </tbody>
                        </table>
                      </div>
                      {!transactions.length && (
                        <div className="empty">
                          <span>↔</span>
                          <h3>{query ? "No matches" : "A fresh start"}</h3>
                          <p>
                            {query
                              ? "Try a different search."
                              : "Add your first transaction to start seeing the bigger picture."}
                          </p>
                        </div>
                      )}
                    </section>
                    <section className="panel">
                      <div className="panel-title">
                        <div>
                          <h3>Add a transaction</h3>
                          <p>Keep your day-to-day in check.</p>
                        </div>
                        <span className="round">+</span>
                      </div>
                      <form onSubmit={addTransaction}>
                        <label>
                          Type
                          <select name="kind">
                            <option value="expense">Expense</option>
                            <option value="income">Income</option>
                          </select>
                        </label>
                        <label>
                          Description
                          <input
                            name="description"
                            placeholder="What was it for?"
                            required
                            maxLength={160}
                          />
                        </label>
                        <div className="form-row">
                          <label>
                            Amount (€)
                            <input
                              name="amount"
                              type="number"
                              step="0.01"
                              min="0.01"
                              max="1000000000"
                              placeholder="0.00"
                              required
                            />
                          </label>
                          <label>
                            Date
                            <input
                              name="date"
                              type="date"
                              defaultValue={today()}
                              required
                            />
                          </label>
                        </div>
                        <label>
                          Account
                          <select name="accountId">
                            {data.accounts.map((a) => (
                              <option key={a.id} value={a.id}>
                                {a.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <label>
                          Category
                          <select name="categoryId">
                            {data.categories.map((c) => (
                              <option key={c.id} value={c.id}>
                                {c.name}
                              </option>
                            ))}
                          </select>
                        </label>
                        <button className="primary" disabled={busy}>
                          {busy ? "Saving…" : "＋ Add transaction"}
                        </button>
                      </form>
                    </section>
                  </div>
                </>
              )}
              {view !== "Transactions" && (
                <section className="panel accounts">
                  <div className="panel-title">
                    <div>
                      <h3>Your accounts</h3>
                      <p>A home for every euro.</p>
                    </div>
                  </div>
                  <div className="account-list">
                    {data.accounts.map((a) => (
                      <article key={a.id}>
                        <span>▣</span>
                        <div>
                          <strong>{a.name}</strong>
                          <small>EUR · Personal account</small>
                        </div>
                        <b>
                          {money(
                            a.opening +
                              data.transactions
                                .filter((t) => t.accountId === a.id)
                                .reduce((s, t) => s + t.amount, 0),
                          )}
                        </b>
                      </article>
                    ))}
                  </div>
                  <form className="account-form" onSubmit={addAccount}>
                    <label>
                      Account name
                      <input
                        name="name"
                        placeholder="e.g. Savings"
                        required
                        maxLength={80}
                      />
                    </label>
                    <label>
                      Opening balance (€)
                      <input
                        name="opening"
                        type="number"
                        step="0.01"
                        min="-1000000000"
                        max="1000000000"
                        defaultValue="0"
                        required
                      />
                    </label>
                    <button className="secondary" disabled={busy}>
                      ＋ Add account
                    </button>
                  </form>
                </section>
              )}
            </>
          )}
          <footer>
            Made for your everyday.{" "}
            <span>EUR · Local storage · Single user</span>
          </footer>
        </div>
      </main>
    </div>
  );
}
