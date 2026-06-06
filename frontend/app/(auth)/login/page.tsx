"use client";

import Link from "next/link";
import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { useAuthStore } from "@/lib/stores/authStore";
import { resendVerificationApi } from "@/lib/api";
import { GoogleLogin } from "@react-oauth/google";

export default function LoginPage() {
  const router = useRouter();
  const login = useAuthStore((s) => s.login);
  const loginWithGoogle = useAuthStore((s) => s.loginWithGoogle);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [needsVerification, setNeedsVerification] = useState(false);
  const [resendMsg, setResendMsg] = useState("");

  const handleGoogleSuccess = async (credentialResponse: any) => {
    if (!credentialResponse.credential) {
      setError("Google login failed. No credential received.");
      return;
    }
    try {
      setLoading(true);
      setError("");
      // Send the ID token, not the access token
      await loginWithGoogle(credentialResponse.credential);
      router.push("/");
    } catch (err: any) {
      setError(err?.data?.error || "Google login failed.");
    } finally {
      setLoading(false);
    }
  };

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setNeedsVerification(false);
    setResendMsg("");
    setLoading(true);
    try {
      await login(email, password);
      router.push("/");
    } catch (err: unknown) {
      const apiErr = err as { message?: string; data?: { needs_verification?: boolean; error?: string } };
      if (apiErr.data?.needs_verification) {
        setNeedsVerification(true);
        setError(apiErr.data?.error || "Please verify your email before logging in.");
      } else {
        setError(apiErr.data?.error || apiErr.message || "Login failed. Please try again.");
      }
    } finally {
      setLoading(false);
    }
  }

  async function handleResendVerification() {
    try {
      const res = await resendVerificationApi(email);
      setResendMsg(res.message);
    } catch {
      setResendMsg("Could not resend verification email. Please try again.");
    }
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
        <h2 className="text-3xl font-bold text-white mb-3">Welcome Back</h2>
        <p className="text-text-muted">
          Enter your credentials to access your dashboard
        </p>
      </div>

      {/* Auth Tabs */}
      <div className="flex bg-surface-elevated/50 p-1 rounded-xl w-64 mb-10">
        <div className="flex-1 text-center py-2 bg-brand-green/20 text-brand-green rounded-lg text-sm font-bold cursor-pointer">
          Login
        </div>
        <Link href="/register" className="flex-1 text-center py-2 text-text-muted hover:text-white rounded-lg text-sm font-medium transition-colors">
          Sign Up
        </Link>
      </div>

      {/* Error Message */}
      {error && (
        <div className="w-full mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm text-center">
          {error}
          {needsVerification && (
            <button
              type="button"
              onClick={handleResendVerification}
              className="block mx-auto mt-2 text-auth-green hover:underline text-sm font-semibold"
            >
              Resend verification email
            </button>
          )}
          {resendMsg && (
            <p className="mt-2 text-auth-green text-xs">{resendMsg}</p>
          )}
        </div>
      )}

      <form className="w-full space-y-5" onSubmit={handleSubmit}>
        <Input 
          id="email" 
          type="email" 
          label="Email Address" 
          placeholder="name@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5" suppressHydrationWarning>
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
            </svg>
          }
        />
        
        <Input 
          id="password" 
          type="password" 
          label="Password" 
          placeholder="••••••••"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5" suppressHydrationWarning>
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          }
        />

        <div className="flex items-center justify-between pt-2">
          <label className="flex items-center gap-2 cursor-pointer">
            <input type="checkbox" className="w-4 h-4 rounded border-border-input bg-bg-auth text-brand-green focus:ring-brand-green focus:ring-offset-bg-auth" />
            <span className="text-sm text-text-muted">Remember me</span>
          </label>
          <Link href="/reset-password" className="text-sm font-semibold text-auth-green hover:underline">
            Forgot password?
          </Link>
        </div>

        <div className="pt-4">
          <Button variant="auth" className="w-full" type="submit" isLoading={loading}>
            Login to FitTech
          </Button>
        </div>

        <div className="relative py-4 flex items-center justify-center">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-border-input"></div>
          </div>
          <div className="relative bg-bg-auth px-4 text-xs font-semibold text-text-placeholder uppercase tracking-widest">
            or
          </div>
        </div>

        <div className="w-full flex justify-center mt-4 h-[44px] overflow-hidden rounded-xl">
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={() => setError("Google login failed.")}
            theme="filled_black"
            text="continue_with"
            shape="rectangular"
            width="100%"
          />
        </div>
      </form>

      <p className="mt-8 text-sm text-text-muted">
        Don&apos;t have an account? <Link href="/register" className="font-semibold text-auth-green hover:underline">Create an account</Link>
      </p>
    </div>
  );
}
