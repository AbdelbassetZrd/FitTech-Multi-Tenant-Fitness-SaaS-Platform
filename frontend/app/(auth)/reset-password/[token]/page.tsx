"use client";

import Link from "next/link";
import { useState, FormEvent } from "react";
import { useParams } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { resetPasswordConfirmApi } from "@/lib/api";

export default function ResetPasswordConfirmPage() {
  const params = useParams();
  const token = params.token as string;

  const [newPassword, setNewPassword] = useState("");
  const [newPassword2, setNewPassword2] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");

    if (newPassword !== newPassword2) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    try {
      await resetPasswordConfirmApi(token, newPassword, newPassword2);
      setSuccess(true);
    } catch (err: unknown) {
      const apiErr = err as { message?: string };
      setError(apiErr.message || "Failed to reset password. The link may be invalid or expired.");
    } finally {
      setLoading(false);
    }
  }

  if (success) {
    return (
      <div className="flex flex-col items-center w-full">
        <div className="w-16 h-16 rounded-full bg-auth-green/20 flex items-center justify-center mb-6">
          <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-8 h-8 text-auth-green">
            <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <h2 className="text-2xl font-bold text-white mb-3">Password Reset!</h2>
        <p className="text-[#94A3B8] text-center mb-8 max-w-sm">
          Your password has been reset successfully. You can now log in with your new password.
        </p>
        <Link href="/login">
          <Button variant="auth">Go to Login</Button>
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
        <h2 className="text-3xl font-bold text-white mb-3">Set New Password</h2>
        <p className="text-[#94A3B8]">
          Enter your new password below.
        </p>
      </div>

      {error && (
        <div className="w-full mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm text-center">
          {error}
        </div>
      )}

      <form className="w-full space-y-5" onSubmit={handleSubmit}>
        <Input
          id="new_password"
          type="password"
          label="New Password"
          placeholder="••••••••"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          required
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          }
        />

        <Input
          id="new_password2"
          type="password"
          label="Confirm New Password"
          placeholder="••••••••"
          value={newPassword2}
          onChange={(e) => setNewPassword2(e.target.value)}
          required
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          }
        />

        <div className="pt-4">
          <Button variant="auth" className="w-full" type="submit" isLoading={loading}>
            Reset Password
          </Button>
        </div>
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
