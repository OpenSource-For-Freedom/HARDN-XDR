const features = [
  {
    title: "DISA STIG Compliance",
    description: "Comprehensive implementation of Defense Information Systems Agency Security Technical Implementation Guides for government-grade security standards."
  },
  {
    title: "CIS Controls",
    description: "Center for Internet Security benchmark implementation with automated hardening for industry-standard security configurations."
  },
  {
    title: "FIPS 140-2",
    description: "Federal cryptographic standards compliance ensuring secure cryptographic implementations and key management."
  },
  {
    title: "Multi-Architecture",
    description: "Native support for AMD64 and ARM64 architectures with optimized container and VM-first deployment strategies."
  },
  {
    title: "Real-time Monitoring",
    description: "Matrix-themed compliance dashboard with real-time security metrics, audit trails, and comprehensive reporting."
  },
  {
    title: "Automated Hardening",
    description: "41+ security modules providing automated system hardening, malware detection, and continuous compliance validation."
  }
];

export default function FeatureGrid() {
  return (
    <section className="py-16">
      <div className="max-w-7xl mx-auto px-6">
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, index) => (
            <div
              key={index}
              className="feature-card p-8 rounded-lg"
            >
              <h3 className="text-xl font-bold mb-4 text-blue-300 font-['Orbitron']">
                {feature.title}
              </h3>
              <p className="text-gray-300 leading-relaxed">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}