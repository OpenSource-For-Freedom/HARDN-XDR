export default function Header() {
  return (
    <header className="relative py-24 text-center">
      <div className="max-w-4xl mx-auto px-6">
        <h1 className="text-6xl md:text-8xl font-black mb-6 font-['Orbitron'] text-blue-300 tracking-wider">
          HARDN-XDR
        </h1>
        <p className="text-xl md:text-2xl text-gray-300 mb-6 font-semibold tracking-wide">
          Advanced Linux Security Hardening Platform
        </p>
        <p className="text-lg text-gray-400 leading-relaxed max-w-3xl mx-auto">
          Government-grade security compliance for Debian-based systems with DISA STIG, CIS Controls, and FIPS 140-2 compliance
        </p>
      </div>
    </header>
  );
}