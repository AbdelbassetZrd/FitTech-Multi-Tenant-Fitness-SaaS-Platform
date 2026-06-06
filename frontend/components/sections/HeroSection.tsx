"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { useAuthStore } from "@/lib/stores/authStore";

export const HeroSection = () => {
  const [mounted, setMounted] = useState(false);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <section className="relative w-full flex flex-col items-center justify-center pt-36 pb-32 px-6 text-center overflow-hidden">
      {/* Animated Background Gradients */}
      <div suppressHydrationWarning className="absolute top-0 left-1/2 -translate-x-1/2 w-full max-w-[800px] h-[600px] bg-brand-green/15 rounded-full blur-[120px] pointer-events-none animate-gradient" style={{ backgroundImage: "linear-gradient(135deg, rgba(46,204,112,0.15), rgba(4,120,87,0.1), rgba(46,204,112,0.2))", backgroundSize: "300% 300%" }} />
      <div className="absolute top-20 right-1/4 w-[400px] h-[400px] bg-brand-green-dark/10 rounded-full blur-[100px] pointer-events-none animate-float" />
      <div className="absolute bottom-10 left-1/4 w-[300px] h-[300px] bg-brand-green/5 rounded-full blur-[80px] pointer-events-none animate-float delay-500" />

      <div className="relative z-10 max-w-4xl mx-auto flex flex-col items-center">
        {/* Label */}
        <div className="inline-block border border-brand-green/30 bg-brand-green/10 text-brand-green text-xs font-bold tracking-widest px-4 py-1.5 rounded-full mb-8 animate-fade-in-up animate-float">
          PERFORMANCE ECOSYSTEM
        </div>

        {/* Heading */}
        <h1 className="text-5xl md:text-7xl lg:text-[80px] font-bold text-white uppercase leading-[1.1] mb-6 animate-fade-in-up delay-200">
          EVOLVE YOUR <br className="hidden md:block" /> <span className="text-transparent bg-clip-text bg-gradient-to-r from-brand-green via-brand-green-light to-brand-green">GRIND</span>
        </h1>

        {/* Description */}
        <p className="text-lg md:text-xl text-text-muted max-w-2xl mb-10 animate-fade-in-up delay-400">
          The all-in-one ecosystem for tracking, training, and transforming your fitness journey with precision data and elite gear.
        </p>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row items-center gap-4 animate-fade-in-up delay-600">
          {mounted && isAuthenticated ? (
            <Link href={user?.role === 'admin' ? '/admin' : '/dashboard'} className="w-full sm:w-auto">
              <Button variant="primary" size="lg" className="w-full sm:w-auto uppercase animate-pulse-glow">
                Go to Dashboard
              </Button>
            </Link>
          ) : mounted && !isAuthenticated ? (
            <Link href="/register" className="w-full sm:w-auto">
              <Button variant="primary" size="lg" className="w-full sm:w-auto uppercase animate-pulse-glow">
                Get Started Now
              </Button>
            </Link>
          ) : (
             <Button variant="primary" size="lg" className="w-full sm:w-auto uppercase invisible">
               Loading
             </Button>
          )}
          <Link href="#demo">
            <Button variant="outline" size="lg" className="w-full sm:w-auto uppercase">
              View Demo
            </Button>
          </Link>
        </div>
      </div>
    </section>
  );
};
