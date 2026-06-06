"use client";

import { useState, useEffect } from "react";
import { useAuthStore } from "@/lib/stores/authStore";
import { updateProfileApi, changePasswordApi } from "@/lib/api";
import { Input } from "@/components/ui/Input";
import { Button } from "@/components/ui/Button";

export default function ProfileSettingsPage() {
  const user = useAuthStore((s) => s.user);
  const accessToken = useAuthStore((s) => s.accessToken);
  const setUser = useAuthStore((s) => s.setUser);

  // Profile Form State
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [phone, setPhone] = useState("");
  const [bio, setBio] = useState("");
  const [fitnessGoal, setFitnessGoal] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");

  const [profileMsg, setProfileMsg] = useState({ text: "", type: "" });
  const [profileLoading, setProfileLoading] = useState(false);

  // Password Form State
  const [oldPassword, setOldPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [newPassword2, setNewPassword2] = useState("");

  const [passwordMsg, setPasswordMsg] = useState({ text: "", type: "" });
  const [passwordLoading, setPasswordLoading] = useState(false);

  // Initialize profile form
  useEffect(() => {
    if (user) {
      setFirstName(user.first_name || "");
      setLastName(user.last_name || "");
      setPhone(user.phone || "");
      setBio(user.bio || "");
      setFitnessGoal(user.fitness_goal || "");
      setDateOfBirth(user.date_of_birth || "");
    }
  }, [user]);

  async function handleUpdateProfile(e: React.FormEvent) {
    e.preventDefault();
    if (!accessToken) return;

    setProfileLoading(true);
    setProfileMsg({ text: "", type: "" });
    try {
      const updatedUser = await updateProfileApi(
        { first_name: firstName, last_name: lastName, phone, bio, fitness_goal: fitnessGoal, date_of_birth: dateOfBirth || null },
        accessToken
      );
      setUser(updatedUser);
      setProfileMsg({ text: "Profile updated successfully!", type: "success" });
    } catch (err: unknown) {
      const apiErr = err as { message?: string; data?: { error?: string } };
      setProfileMsg({
        text: apiErr.data?.error || apiErr.message || "Failed to update profile.",
        type: "error",
      });
    } finally {
      setProfileLoading(false);
    }
  }

  async function handleChangePassword(e: React.FormEvent) {
    e.preventDefault();
    if (!accessToken) return;

    if (newPassword !== newPassword2) {
      setPasswordMsg({ text: "Passwords do not match.", type: "error" });
      return;
    }

    setPasswordLoading(true);
    setPasswordMsg({ text: "", type: "" });

    try {
      const res = await changePasswordApi(
        { old_password: oldPassword, new_password: newPassword, new_password2: newPassword2 },
        accessToken
      );
      setPasswordMsg({ text: res.message || "Password changed successfully!", type: "success" });
      setOldPassword("");
      setNewPassword("");
      setNewPassword2("");
    } catch (err: unknown) {
      const apiErr = err as { message?: string; data?: { error?: string; [key: string]: unknown } };

      let errorText = "Failed to change password.";
      if (apiErr.data?.old_password) errorText = (apiErr.data.old_password as string[])[0];
      else if (apiErr.data?.new_password) errorText = (apiErr.data.new_password as string[])[0];
      else if (apiErr.data?.non_field_errors) errorText = (apiErr.data.non_field_errors as string[])[0];
      else if (apiErr.message) errorText = apiErr.message;

      setPasswordMsg({ text: errorText, type: "error" });
    } finally {
      setPasswordLoading(false);
    }
  }

  const completion = user?.profile_completion_percentage ?? 0;

  const roleColor = user?.role === 'admin' ? 'text-red-400 bg-red-500/10 border-red-500/20'
    : user?.role === 'coach' ? 'text-amber-400 bg-amber-500/10 border-amber-500/20'
    : 'text-brand-green bg-brand-green/10 border-brand-green/20';

  return (
    <div className="space-y-8 animate-fade-in-up">

      {/* ── Profile Header Card ─────────────────────────────────── */}
      <div className="relative bg-surface-elevated/50 backdrop-blur-xl border border-white/5 rounded-3xl p-6 md:p-8 overflow-hidden">
        {/* Background decoration */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-brand-green/5 rounded-full blur-3xl -mr-20 -mt-20 pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-48 h-48 bg-violet-500/3 rounded-full blur-3xl -ml-20 -mb-20 pointer-events-none" />

        <div className="relative z-10 flex flex-col sm:flex-row items-center gap-6">
          {/* Avatar with gradient border */}
          <div className="relative flex-shrink-0">
            <div className="absolute inset-0 bg-gradient-to-br from-brand-green to-brand-green-dark rounded-full blur-md opacity-30" />
            <div className="relative w-20 h-20 rounded-full bg-gradient-to-br from-brand-green/20 to-brand-green-dark/20 border-3 border-brand-green/40 flex items-center justify-center text-brand-green font-black text-3xl shadow-lg shadow-brand-green/10">
              {user?.first_name?.[0]?.toUpperCase() || "U"}
            </div>
          </div>

          {/* User info */}
          <div className="flex-1 text-center sm:text-left">
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 mb-1">
              <h1 className="text-2xl font-black text-white">
                {user?.first_name} {user?.last_name}
              </h1>
              <span className={`inline-flex w-fit mx-auto sm:mx-0 text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-md border ${roleColor}`}>
                {user?.role || "member"}
              </span>
            </div>
            <p className="text-sm text-text-muted mb-3">{user?.email}</p>

            {/* Progress bar */}
            <div className="flex items-center gap-3">
              <div className="flex-1 max-w-xs h-2 bg-white/5 rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-brand-green to-brand-green-light rounded-full transition-all duration-1000 ease-out"
                  style={{ width: `${completion}%` }}
                />
              </div>
              <span className="text-xs font-bold text-text-muted">{completion}% complete</span>
            </div>
          </div>

          {/* Verification badge */}
          <div className="flex-shrink-0">
            <div className={`flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-semibold ${
              user?.email_verified
                ? 'bg-brand-green/10 text-brand-green border border-brand-green/20'
                : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
            }`}>
              {user?.email_verified ? (
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                </svg>
              )}
              {user?.email_verified ? "Verified" : "Not Verified"}
            </div>
          </div>
        </div>
      </div>

      {/* ── Personal Information Form ───────────────────────────── */}
      <div className="relative bg-surface-elevated/40 backdrop-blur-xl border border-white/5 rounded-3xl p-6 md:p-8 overflow-hidden group transition-all duration-500 hover:border-brand-green/10">
        <div className="absolute top-0 right-0 w-40 h-40 bg-brand-green/3 rounded-full blur-3xl -mr-16 -mt-16 opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-xl bg-brand-green/15 flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Personal Information</h2>
              <p className="text-xs text-text-muted">Update your name, contact details, and bio</p>
            </div>
          </div>

          <form onSubmit={handleUpdateProfile} className="space-y-5">
            {profileMsg.text && (
              <div className={`flex items-center gap-2 p-3.5 rounded-xl border text-sm font-medium ${profileMsg.type === 'success' ? 'bg-green-500/10 border-green-500/20 text-green-400' : 'bg-red-500/10 border-red-500/20 text-red-400'}`}>
                {profileMsg.type === 'success' ? (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 flex-shrink-0"><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                ) : (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 flex-shrink-0"><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>
                )}
                {profileMsg.text}
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <Input
                id="firstName" label="First Name" placeholder="John"
                value={firstName} onChange={(e) => setFirstName(e.target.value)}
                required
              />
              <Input
                id="lastName" label="Last Name" placeholder="Doe"
                value={lastName} onChange={(e) => setLastName(e.target.value)}
                required
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <Input
                id="phone" type="tel" label="Phone Number" placeholder="+1 234 567 8900"
                value={phone} onChange={(e) => setPhone(e.target.value)}
              />
              <Input
                id="dateOfBirth" type="date" label="Date of Birth"
                value={dateOfBirth} onChange={(e) => setDateOfBirth(e.target.value)}
              />
            </div>

            <Input
              id="fitnessGoal" label="Fitness Goal" placeholder="e.g. Build muscle, lose weight, improve endurance..."
              value={fitnessGoal} onChange={(e) => setFitnessGoal(e.target.value)}
            />

            <div className="flex flex-col space-y-2 w-full">
              <label htmlFor="bio" className="text-sm font-semibold text-text-label">Bio</label>
              <textarea
                id="bio"
                rows={3}
                placeholder="Tell us a bit about yourself and your fitness journey..."
                value={bio}
                onChange={(e) => setBio(e.target.value)}
                className="w-full bg-bg-auth border border-border-input rounded-2xl text-sm text-white placeholder:text-text-placeholder focus:outline-none focus:ring-2 focus:ring-brand-green focus:border-transparent focus:shadow-[0_0_20px_rgba(46,204,112,0.12)] transition-all duration-300 py-4 px-4 resize-none"
              ></textarea>
            </div>

            <div className="pt-2">
              <Button type="submit" variant="auth" isLoading={profileLoading} className="w-full sm:w-auto px-8 shadow-lg shadow-brand-green/15">
                Save Changes
              </Button>
            </div>
          </form>
        </div>
      </div>

      {/* ── Change Password Form ────────────────────────────────── */}
      <div className="relative bg-surface-elevated/40 backdrop-blur-xl border border-white/5 rounded-3xl p-6 md:p-8 overflow-hidden group transition-all duration-500 hover:border-blue-500/10">
        <div className="absolute top-0 right-0 w-40 h-40 bg-blue-500/3 rounded-full blur-3xl -mr-16 -mt-16 opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none" />

        <div className="relative z-10">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-10 h-10 rounded-xl bg-blue-500/15 flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-blue-400">
                <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
              </svg>
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Change Password</h2>
              <p className="text-xs text-text-muted">Ensure your account stays secure with a strong password</p>
            </div>
          </div>

          <form onSubmit={handleChangePassword} className="space-y-5">
            {passwordMsg.text && (
              <div className={`flex items-center gap-2 p-3.5 rounded-xl border text-sm font-medium ${passwordMsg.type === 'success' ? 'bg-green-500/10 border-green-500/20 text-green-400' : 'bg-red-500/10 border-red-500/20 text-red-400'}`}>
                {passwordMsg.type === 'success' ? (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 flex-shrink-0"><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                ) : (
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 flex-shrink-0"><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" /></svg>
                )}
                {passwordMsg.text}
              </div>
            )}

            <Input
              id="oldPassword" type="password" label="Current Password" placeholder="••••••••"
              value={oldPassword} onChange={(e) => setOldPassword(e.target.value)}
              required
            />

            <div className="flex items-center gap-3 py-1">
              <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
              <span className="text-[10px] font-bold text-text-muted/50 uppercase tracking-widest">New Password</span>
              <div className="flex-1 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <Input
                id="newPassword" type="password" label="New Password" placeholder="••••••••"
                value={newPassword} onChange={(e) => setNewPassword(e.target.value)}
                required
              />
              <Input
                id="newPasswordConfirm" type="password" label="Confirm New Password" placeholder="••••••••"
                value={newPassword2} onChange={(e) => setNewPassword2(e.target.value)}
                required
              />
            </div>

            <div className="pt-2">
              <Button type="submit" className="w-full sm:w-auto px-8 bg-surface-elevated text-white hover:bg-surface-elevated/80 hover:shadow-lg border border-white/10 hover:border-white/20 transition-all duration-300" isLoading={passwordLoading}>
                Update Password
              </Button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
