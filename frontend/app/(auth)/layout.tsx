import Link from "next/link";
import React from "react";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen w-full flex bg-bg-auth">
      {/* Left Side - Hero Image Section */}
      <div className="hidden lg:flex flex-col w-1/2 relative overflow-hidden bg-bg-main">
        {/* Animated gradient overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-bg-auth via-transparent to-transparent z-10" />
        <div className="absolute inset-0 bg-gradient-to-br from-brand-green/5 via-transparent to-brand-green-dark/10 z-10 animate-gradient" style={{ backgroundSize: "300% 300%" }} />
        <div 
          className="absolute inset-0 bg-cover bg-center opacity-40 mix-blend-luminosity" 
          style={{ backgroundImage: "url('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=2070&auto=format&fit=crop')" }}
        />
        
        {/* Decorative orbs */}
        <div className="absolute bottom-20 right-10 w-64 h-64 bg-brand-green/10 rounded-full blur-[80px] pointer-events-none animate-float" />
        <div className="absolute top-40 left-10 w-48 h-48 bg-brand-green-dark/10 rounded-full blur-[60px] pointer-events-none animate-float delay-300" />

        {/* Branding & Overlay Content */}
        <div className="relative z-20 flex flex-col h-full p-12 justify-between">
          <Link href="/" className="flex items-center gap-2 w-fit group animate-fade-in">
            <div className="w-8 h-8 rounded bg-brand-green flex items-center justify-center text-bg-main font-bold transition-transform duration-300 group-hover:scale-110">
              F
            </div>
            <span className="text-xl font-bold tracking-widest text-white">
              FITTECH
            </span>
          </Link>

          <div className="mb-20 animate-fade-in-up delay-200">
            <div className="inline-block bg-brand-green text-[#131F18] text-xs font-bold tracking-widest px-4 py-1.5 rounded-full mb-6 uppercase animate-shimmer bg-gradient-to-r from-brand-green via-brand-green-light to-brand-green" style={{ backgroundSize: "200% auto" }}>
              Join the Elite
            </div>
            <h1 className="text-5xl xl:text-7xl font-bold text-white uppercase leading-tight mb-6">
              ELEVATE YOUR <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-brand-green to-brand-green-light">PERFORMANCE</span>
            </h1>
            <p className="text-lg text-white/80 max-w-md">
              The all-in-one ecosystem for tracking, training, and transforming your fitness journey.
            </p>
          </div>
          
          <div className="flex items-center gap-4 animate-fade-in delay-400">
            <div className="flex -space-x-3">
              <div className="w-10 h-10 rounded-full bg-gray-600 border-2 border-bg-auth" />
              <div className="w-10 h-10 rounded-full bg-gray-500 border-2 border-bg-auth" />
              <div className="w-10 h-10 rounded-full bg-gray-400 border-2 border-bg-auth" />
            </div>
            <p className="text-sm font-medium text-white/80">
              Join <strong className="text-white">12,000+</strong> active athletes today.
            </p>
          </div>
        </div>
      </div>

      {/* Right Side - Auth Forms */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-6 sm:p-12 relative overflow-hidden">
        {/* Subtle background glow */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-brand-green/3 rounded-full blur-[120px] pointer-events-none" />
        
        <div className="w-full max-w-md relative z-10 animate-fade-in-up">
          {children}
        </div>
      </div>
    </div>
  );
}
