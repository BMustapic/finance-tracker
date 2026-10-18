import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "Pocket · Personal finance",
  description: "A clearer picture of your money",
};
export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
