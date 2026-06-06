"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { verifyEmailApi } from "@/lib/api";

export default function VerifyEmailPage() {
  const params = useParams();
  const key = params.key as string;

  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!key) return;

    verifyEmailApi(key)
      .then((res) => {
        setMessage(res.message || "Email verified successfully!");
        setStatus("success");
      })
      .catch((err: { message?: string }) => {
        setMessage(err.message || "Invalid or expired verification link.");
        setStatus("error");
      });
  }, [key]);

  return (
    <div className="flex flex-col items-center w-full">
      {/* Mobile Logo */}
      <Link href="/" className="flex lg:hidden items-center gap-2 mb-12">
        <div className="w-8 h-8 rounded bg-brand-green flex items-center justify-center text-bg-main font-bold">
          F
        </div>
        <span className="text-xl font-bold tracking-widest text-white">
          FITTECH
        </span>
      </Link>

      {status === "loading" && (
        <div className="flex flex-col items-center">
          <div className="w-16 h-16 rounded-full bg-[#1E293B] flex items-center justify-center mb-6">
            <svg suppressHydrationWarning className="animate-spin h-8 w-8 text-auth-green" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle suppressHydrationWarning className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path suppressHydrationWarning className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-3">Verifying Your Email</h2>
          <p className="text-[#94A3B8]">Please wait while we verify your email address...</p>
        </div>
      )}

      {status === "success" && (
        <div className="flex flex-col items-center">
          <div className="w-16 h-16 rounded-full bg-auth-green/20 flex items-center justify-center mb-6">
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-8 h-8 text-auth-green">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-3">Email Verified!</h2>
          <p className="text-[#94A3B8] text-center mb-8 max-w-sm">{message}</p>
          <Link href="/login">
            <Button variant="auth">Go to Login</Button>
          </Link>
        </div>
      )}

      {status === "error" && (
        <div className="flex flex-col items-center">
          <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center mb-6">
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-8 h-8 text-red-400">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-3">Verification Failed</h2>
          <p className="text-[#94A3B8] text-center mb-8 max-w-sm">{message}</p>
          <div className="flex gap-4">
            <Link href="/login">
              <Button variant="outline">Go to Login</Button>
            </Link>
          </div>
        </div>
      )}
    </div>
  );
}
