import Link from "next/link";

export const Footer = () => {
  return (
    <footer className="w-full bg-[#0F172A] border-t border-white/5 pt-16 pb-8 px-6 lg:px-20 text-sm animate-fade-in">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12 mb-16">
        {/* Brand/Logo Column */}
        <div className="flex flex-col space-y-4">
          <Link href="/" className="flex items-center gap-2 group">
            <div className="w-8 h-8 rounded bg-brand-green flex items-center justify-center text-bg-main font-bold transition-transform duration-300 group-hover:scale-110 group-hover:rotate-3">
              F
            </div>
            <span className="text-xl font-bold tracking-widest text-white">
              FITTECH
            </span>
          </Link>
          <p className="text-text-muted mt-4">
            Built for the relentless. The ecosystem designed to elevate every aspect of your performance.
          </p>
          <div className="flex items-center gap-4 mt-6">
            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-brand-green/20 hover:text-brand-green hover:scale-110 hover:shadow-lg hover:shadow-brand-green/20 text-white transition-all duration-300">
              X
            </a>
            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-brand-green/20 hover:text-brand-green hover:scale-110 hover:shadow-lg hover:shadow-brand-green/20 text-white transition-all duration-300">
              In
            </a>
            <a href="#" className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-brand-green/20 hover:text-brand-green hover:scale-110 hover:shadow-lg hover:shadow-brand-green/20 text-white transition-all duration-300">
              Fb
            </a>
          </div>
        </div>

        {/* Platform Column */}
        <div className="flex flex-col space-y-4">
          <h4 className="font-bold tracking-widest text-white uppercase mb-2">Platform</h4>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Booking</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Analytics</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Marketplace</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Coaching</Link>
        </div>

        {/* Company Column */}
        <div className="flex flex-col space-y-4">
          <h4 className="font-bold tracking-widest text-white uppercase mb-2">Company</h4>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">About Us</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Partners</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Careers</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Contact</Link>
        </div>

        {/* Legal Column */}
        <div className="flex flex-col space-y-4">
          <h4 className="font-bold tracking-widest text-white uppercase mb-2">Legal</h4>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Privacy</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Terms</Link>
          <Link href="#" className="text-text-muted hover:text-brand-green hover:translate-x-1 transition-all duration-300">Security</Link>
        </div>
      </div>

      <div className="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center border-t border-white/5 pt-8 text-text-muted text-xs">
        <p>&copy; 2024 FITTECH PERFORMANCE SYSTEMS. ALL RIGHTS RESERVED.</p>
        <div className="flex items-center gap-4 mt-4 md:mt-0">
          <span className="flex items-center gap-1">🌐 ENGLISH (US)</span>
          <span className="flex items-center gap-1">🔒 SECURE PAYMENTS</span>
        </div>
      </div>
    </footer>
  );
};
