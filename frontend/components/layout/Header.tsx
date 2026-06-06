"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { useAuthStore } from "@/lib/stores/authStore";

export const Header = () => {
  const [mounted, setMounted] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const logout = useAuthStore((state) => state.logout);
  const user = useAuthStore((state) => state.user);

  useEffect(() => {
    setMounted(true);

    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <header
      className={`fixed top-0 left-0 w-full h-20 flex items-center justify-between px-6 lg:px-[152px] z-50 transition-all duration-500 animate-fade-in ${
        scrolled
          ? "bg-bg-main/80 backdrop-blur-xl border-b border-white/5 shadow-lg shadow-black/20"
          : "bg-transparent"
      }`}
    >
      {/* Logo */}
      <Link href="/" className="flex items-center gap-2 group">
        <div className="w-8 h-8 rounded bg-brand-green flex items-center justify-center text-bg-main font-bold transition-transform duration-300 group-hover:scale-110 group-hover:rotate-3">
          F
        </div>
        <span className="text-xl font-bold tracking-widest text-white">
          FITTECH
        </span>
      </Link>

      {/* Navigation - Desktop */}
      <nav className="hidden md:flex items-center space-x-8 text-sm font-medium">
        <Link href="#features" className="text-white/80 hover:text-brand-green transition-all duration-300 hover:drop-shadow-[0_0_8px_rgba(46,204,112,0.4)]">
          Features
        </Link>
        <Link href="#pricing" className="text-white/80 hover:text-brand-green transition-all duration-300 hover:drop-shadow-[0_0_8px_rgba(46,204,112,0.4)]">
          Pricing
        </Link>
        <Link href="#shop" className="text-white/80 hover:text-brand-green transition-all duration-300 hover:drop-shadow-[0_0_8px_rgba(46,204,112,0.4)]">
          Shop
        </Link>
        <Link href="#stories" className="text-white/80 hover:text-brand-green transition-all duration-300 hover:drop-shadow-[0_0_8px_rgba(46,204,112,0.4)]">
          Success Stories
        </Link>
      </nav>

      {/* Actions */}
      <div className="flex items-center space-x-6">
        {mounted && isAuthenticated ? (
          <>
            <Link
              href={user?.role === "admin" ? "/admin" : "/dashboard"}
              className="text-sm font-semibold text-white hover:text-brand-green transition-all duration-300 hidden sm:block"
            >
              Dashboard
            </Link>
            <Button variant="outline" size="sm" className="hidden sm:inline-flex" onClick={logout}>
              Logout
            </Button>
          </>
        ) : mounted && !isAuthenticated ? (
          <>
            <Link
              href="/login"
              className="text-sm font-semibold text-white hover:text-brand-green transition-all duration-300 hidden sm:block"
            >
              Login
            </Link>
            <Link href="/register">
              <Button variant="primary" size="sm" className="hidden sm:inline-flex">
                Start Now
              </Button>
            </Link>
          </>
        ) : (
          <div className="w-[140px] hidden sm:block h-9"></div>
        )}
        {/* Mobile menu button */}
        <button className="md:hidden text-white p-2 hover:text-brand-green transition-colors duration-300">
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" suppressHydrationWarning>
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>
    </header>
  );
};
