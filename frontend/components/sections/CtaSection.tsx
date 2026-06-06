"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { useAuthStore } from "@/lib/stores/authStore";

export const CtaSection = () => {
  const [mounted, setMounted] = useState(false);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    setMounted(true);
  }, []);

  return (
    <section className="w-full py-24 px-6 bg-bg-main flex justify-center">
      <div 
        className="w-full max-w-5xl rounded-[32px] p-12 md:p-20 flex flex-col md:flex-row items-center justify-between relative overflow-hidden animate-scale-in bg-gradient-to-br from-brand-green via-brand-green-light to-brand-green animate-gradient shadow-[0_25px_60px_rgba(46,204,112,0.3)]"
        style={{ backgroundSize: "300% 300%" }}
      >
        {/* Decorative animated shapes */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl pointer-events-none animate-float" />
        <div className="absolute bottom-0 left-0 w-48 h-48 bg-brand-green-dark/20 rounded-full blur-2xl pointer-events-none animate-float delay-300" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 border border-white/10 rounded-full pointer-events-none animate-spin-slow" />

        <div className="relative z-10 flex flex-col md:w-3/5 text-center md:text-left mb-8 md:mb-0">
          <h2 className="text-4xl md:text-5xl font-bold text-[#131F18] uppercase leading-tight mb-4">
            READY TO REACH YOUR PEAK?
          </h2>
          <p className="text-[#131F18]/80 text-lg font-medium">
            Join 12,000+ elite athletes who have already evolved their grind with FitTech.
          </p>
        </div>
        
        <div className="relative z-10 flex flex-col sm:flex-row items-center gap-4">
          {mounted && isAuthenticated ? (
            <Link href={user?.role === 'admin' ? '/admin' : '/dashboard'} className="w-full sm:w-auto">
              <Button className="bg-[#131F18] text-white hover:bg-[#131F18]/80 hover:shadow-xl hover:shadow-black/20 hover:scale-[1.03] active:scale-[0.97] transition-all duration-300 px-8 py-4 h-auto uppercase w-full">
                GO TO DASHBOARD
              </Button>
            </Link>
          ) : mounted && !isAuthenticated ? (
            <Link href="/register" className="w-full sm:w-auto">
              <Button className="bg-[#131F18] text-white hover:bg-[#131F18]/80 hover:shadow-xl hover:shadow-black/20 hover:scale-[1.03] active:scale-[0.97] transition-all duration-300 px-8 py-4 h-auto uppercase w-full">
                GET STARTED
              </Button>
            </Link>
          ) : (
            <Button className="bg-[#131F18] text-white px-8 py-4 h-auto uppercase w-full sm:w-auto invisible">
              LOADING
            </Button>
          )}
          <Button className="bg-transparent border-2 border-[#131F18] text-[#131F18] hover:bg-[#131F18]/10 hover:shadow-lg hover:scale-[1.03] active:scale-[0.97] transition-all duration-300 px-8 py-4 h-auto uppercase w-full sm:w-auto">
            CONTACT US
          </Button>
        </div>
      </div>
    </section>
  );
};
