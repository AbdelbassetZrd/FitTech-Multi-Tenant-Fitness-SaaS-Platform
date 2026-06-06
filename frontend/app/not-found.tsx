"use client";

import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { ArrowLeft, Home } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-screen w-full flex flex-col items-center justify-center relative overflow-hidden bg-bg-main">
      {/* Background Decorative Elements */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-brand-green/20 rounded-full blur-[120px] animate-pulse-glow pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-brand-green-light/10 rounded-full blur-[100px] animate-pulse-glow pointer-events-none delay-500" />
      
      {/* Main Content Container */}
      <div className="z-10 flex flex-col items-center text-center space-y-8 p-6 glass rounded-3xl border border-white/5 shadow-2xl max-w-2xl w-full mx-4 animate-scale-in">
        
        {/* Glowing 404 Text */}
        <div className="relative">
          <h1 className="text-[150px] sm:text-[200px] leading-none font-black text-transparent bg-clip-text bg-gradient-to-br from-brand-green via-brand-green-light to-white animate-gradient drop-shadow-[0_0_40px_rgba(46,204,112,0.4)]">
            404
          </h1>
          <div className="absolute inset-0 bg-brand-green/20 blur-3xl rounded-full -z-10 animate-pulse-glow"></div>
        </div>

        {/* Messaging */}
        <div className="space-y-4 animate-fade-in-up delay-200">
          <h2 className="text-3xl sm:text-4xl font-bold text-white tracking-tight">
            Page Not Found
          </h2>
          <p className="text-lg text-text-muted max-w-md mx-auto">
            Looks like this page took a rest day. Don't worry, even the best routines need a slight adjustment. Let's get you back on track.
          </p>
        </div>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row items-center gap-4 pt-6 animate-fade-in-up delay-300 w-full sm:w-auto">
          <Link href="/" passHref className="w-full sm:w-auto">
            <Button variant="primary" size="lg" className="w-full sm:w-auto flex items-center justify-center gap-2 group">
              <Home className="w-5 h-5 transition-transform group-hover:scale-110" />
              <span>Back to Home</span>
            </Button>
          </Link>
          <Button 
            variant="outline" 
            size="lg" 
            onClick={() => window.history.back()}
            className="w-full sm:w-auto flex items-center justify-center gap-2 group"
          >
            <ArrowLeft className="w-5 h-5 transition-transform group-hover:-translate-x-1" />
            <span>Go Back</span>
          </Button>
        </div>
      </div>
      
      {/* Floating Elements for aesthetics */}
      <div className="absolute top-20 left-10 w-4 h-4 rounded-full bg-brand-green/50 animate-float delay-100" />
      <div className="absolute bottom-40 right-20 w-6 h-6 rounded-full bg-brand-green-light/40 animate-float delay-300" />
      <div className="absolute top-1/2 right-10 w-3 h-3 rounded-full bg-white/20 animate-float delay-700" />
    </div>
  );
}
