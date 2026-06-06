"use client";

import Link from "next/link";
import { useState, FormEvent } from "react";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";
import { registerApi } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";
import { GoogleLogin } from "@react-oauth/google";
import { useRouter } from "next/navigation";

export default function RegisterPage() {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [password2, setPassword2] = useState("");
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({});
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const router = useRouter();
  const loginWithGoogle = useAuthStore((s) => s.loginWithGoogle);

  const handleGoogleSuccess = async (credentialResponse: any) => {
    if (!credentialResponse.credential) {
      setError("Google login failed. No credential received.");
      return;
    }
    try {
      setLoading(true);
      setError("");
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
    setFieldErrors({});

    if (password !== password2) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);
    try {
      await registerApi({
        email,
        password,
        password2,
        first_name: firstName,
        last_name: lastName,
      });
      setSuccess(true);
    } catch (err: unknown) {
      const apiErr = err as { message?: string; data?: Record<string, unknown> };
      // Backend may return field-level errors
      if (apiErr.data && typeof apiErr.data === "object") {
        const errs: Record<string, string[]> = {};
        let generalError = "";
        for (const [key, val] of Object.entries(apiErr.data)) {
          if (key === "error" || key === "detail") {
            generalError = String(val);
          } else if (Array.isArray(val)) {
            errs[key] = val.map(String);
          }
        }
        setFieldErrors(errs);
        if (generalError) setError(generalError);
        else if (Object.keys(errs).length === 0) {
          setError(apiErr.message || "Registration failed.");
        }
      } else {
        setError(apiErr.message || "Registration failed. Please try again.");
      }
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
          We&apos;ve sent a verification link to <strong className="text-white">{email}</strong>. 
          Please verify your email before logging in.
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
        <h2 className="text-3xl font-bold text-white mb-3">Create an Account</h2>
        <p className="text-text-muted">
          Join the elite and track your fitness journey
        </p>
      </div>

      {/* Auth Tabs */}
      <div className="flex bg-surface-elevated/50 p-1 rounded-xl w-64 mb-10">
        <Link href="/login" className="flex-1 text-center py-2 text-text-muted hover:text-white rounded-lg text-sm font-medium transition-colors">
          Login
        </Link>
        <div className="flex-1 text-center py-2 bg-brand-green/20 text-brand-green rounded-lg text-sm font-bold cursor-pointer">
          Sign Up
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="w-full mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-sm text-center">
          {error}
        </div>
      )}

      <form className="w-full space-y-5" onSubmit={handleSubmit}>
        <div className="grid grid-cols-2 gap-4">
          <Input 
            id="first_name" 
            type="text" 
            label="First Name" 
            placeholder="Jane"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
            required
            error={fieldErrors.first_name?.[0]}
            icon={
              <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
            }
          />
          <Input 
            id="last_name" 
            type="text" 
            label="Last Name" 
            placeholder="Doe"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
            required
            error={fieldErrors.last_name?.[0]}
            icon={
              <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
            }
          />
        </div>

        <Input 
          id="email" 
          type="email" 
          label="Email Address" 
          placeholder="name@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          error={fieldErrors.email?.[0]}
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
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
          error={fieldErrors.password?.[0]}
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          }
        />

        <Input 
          id="password2" 
          type="password" 
          label="Confirm Password" 
          placeholder="••••••••"
          value={password2}
          onChange={(e) => setPassword2(e.target.value)}
          required
          icon={
            <svg suppressHydrationWarning xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
              <path suppressHydrationWarning strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
          }
        />

        <div className="pt-4">
          <Button variant="auth" className="w-full" type="submit" isLoading={loading}>
            Create Account
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
        Already have an account? <Link href="/login" className="font-semibold text-auth-green hover:underline">Log in</Link>
      </p>
    </div>
  );
}
