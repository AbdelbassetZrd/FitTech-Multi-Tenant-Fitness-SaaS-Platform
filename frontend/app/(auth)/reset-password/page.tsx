"use client";

import Link from "next/link";
import { useState, FormEvent } from "react";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { resetPasswordRequestApi } from "@/lib/api";

export default function ResetPasswordPage() {
  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await resetPasswordRequestApi(email);
      setSuccess(true);
    } catch (err: unknown) {
      const apiErr = err as { message?: string };
      setError(apiErr.message || "Failed to send reset link. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  if (success) {
    return (
      <div className="flex flex-col items-center w-full">
        <div className="w-16 h-16 rounded-full bg-auth-green/20 flex items-center justify-center mb-6">
          <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-8 h-8 text-auth-green">
            <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
          </svg>
        </div>
        <h2 className="text-2xl font-bold text-white mb-3">Check Your Email</h2>
        <p className="text-[#94A3B8] text-center mb-8 max-w-sm">
          If an account exists for <strong className="text-white">{email}</strong>, we&apos;ve sent a password reset link.
        </p>
        <Link href="/login">
          <Button variant="auth">Back to Login</Button>
        </Link>
      </div>
    );
  }

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

      <div className="text-center mb-10">
        <h2 className="text-3xl font-bold text-white mb-3">Reset Password</h2>
        <p className="text-[#94A3B8]">
          Enter your email and we&apos;ll send you a link to reset your password.
        </p>
      </div>

      {error && (
        <div className="w-full mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm text-center">
          {error}
        </div>
      )}

      <form className="w-full space-y-6" onSubmit={handleSubmit}>
        <Input 
          id="email" 
          type="email" 
          label="Email Address" 
          placeholder="name@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
            </svg>
          }
        />

        <Button variant="auth" className="w-full" type="submit" isLoading={loading}>
          Send Reset Link
        </Button>
      </form>

      <Link href="/login" className="mt-8 text-sm font-semibold text-auth-green hover:underline flex items-center gap-2">
        <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
          <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
        </svg>
        Back to Login
      </Link>
    </div>
  );
}
