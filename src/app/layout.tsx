import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "HARDN-XDR | Advanced Linux Security Platform",
  description: "Government-grade security compliance for Debian-based systems with DISA STIG, CIS Controls, and FIPS 140-2 compliance",
  keywords: ["Linux security", "DISA STIG", "CIS Controls", "FIPS 140-2", "security hardening", "compliance"],
  authors: [{ name: "Security International Group" }],
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="icon" type="image/png" href="/HARDN-XDR/sig_logo.png" />
      </head>
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
