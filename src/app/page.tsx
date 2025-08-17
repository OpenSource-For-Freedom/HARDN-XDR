import Header from '@/components/Header';
import TerminalDemo from '@/components/TerminalDemo';
import FeatureGrid from '@/components/FeatureGrid';
import Footer from '@/components/Footer';
import MatrixBackground from '@/components/MatrixBackground';

export default function Home() {
  return (
    <div className="min-h-screen relative">
      <div className="matrix-bg"></div>
      <MatrixBackground />
      
      <div className="relative z-10">
        <div className="max-w-7xl mx-auto">
          <Header />
          <TerminalDemo />
          <FeatureGrid />
        </div>
        <Footer />
      </div>
    </div>
  );
}
