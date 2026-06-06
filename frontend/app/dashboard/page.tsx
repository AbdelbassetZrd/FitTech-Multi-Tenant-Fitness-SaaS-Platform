"use client";

import Link from "next/link";
import { useAuthStore } from "@/lib/stores/authStore";

/* ── SVG Progress Ring ─────────────────────────────────────────────────── */
function ProgressRing({ percentage, size = 80, strokeWidth = 6 }: { percentage: number; size?: number; strokeWidth?: number }) {
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (percentage / 100) * circumference;

  return (
    <div className="relative" style={{ width: size, height: size }}>
      <svg className="transform -rotate-90" width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={radius} stroke="rgba(255,255,255,0.08)" strokeWidth={strokeWidth} fill="none" />
        <circle
          cx={size / 2} cy={size / 2} r={radius}
          stroke="url(#greenGradient)" strokeWidth={strokeWidth} fill="none"
          strokeLinecap="round"
          strokeDasharray={circumference} strokeDashoffset={offset}
          className="transition-all duration-1000 ease-out"
        />
        <defs>
          <linearGradient id="greenGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#2ECC70" />
            <stop offset="100%" stopColor="#34D399" />
          </linearGradient>
        </defs>
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className="text-lg font-black text-white">{percentage}%</span>
      </div>
    </div>
  );
}

/* ── Stat Card ─────────────────────────────────────────────────────────── */
function StatCard({ icon, label, value, accent, subtext }: {
  icon: React.ReactNode; label: string; value: string; accent: string; subtext?: string;
}) {
  return (
    <div className="bg-surface-elevated/50 backdrop-blur-md rounded-2xl border border-white/5 p-5 transition-all duration-500 hover:border-white/10 hover:-translate-y-1 hover:shadow-xl group">
      <div className="flex items-start justify-between mb-3">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all duration-300 group-hover:scale-110 ${accent}`}>
          {icon}
        </div>
      </div>
      <p className="text-xs font-semibold text-text-muted/70 uppercase tracking-wider mb-1">{label}</p>
      <p className="text-2xl font-black text-white">{value}</p>
      {subtext && <p className="text-xs text-text-muted mt-1">{subtext}</p>}
    </div>
  );
}

/* ── Quick Action Card ─────────────────────────────────────────────────── */
function ActionCard({ icon, title, description, href, accentBg, accentBorder }: {
  icon: React.ReactNode; title: string; description: string; href: string; accentBg: string; accentBorder: string;
}) {
  return (
    <Link href={href} className="block group">
      <div className={`relative bg-surface-elevated/40 backdrop-blur-md rounded-2xl border border-white/5 p-6 transition-all duration-500 hover:-translate-y-2 hover:shadow-2xl overflow-hidden ${accentBorder}`}>
        {/* Hover glow */}
        <div className={`absolute top-0 right-0 w-32 h-32 rounded-full blur-3xl -mr-16 -mt-16 opacity-0 group-hover:opacity-100 transition-opacity duration-500 ${accentBg}`} />
        
        <div className="relative z-10">
          <div className={`w-12 h-12 rounded-xl flex items-center justify-center mb-4 transition-all duration-300 group-hover:scale-110 ${accentBg}`}>
            {icon}
          </div>
          <h3 className="text-lg font-bold text-white mb-1.5 group-hover:text-brand-green transition-colors duration-300">{title}</h3>
          <p className="text-sm text-text-muted leading-relaxed mb-4">{description}</p>
          <div className="flex items-center gap-2 text-sm font-semibold text-brand-green opacity-0 group-hover:opacity-100 translate-y-2 group-hover:translate-y-0 transition-all duration-300">
            Open <span>&rarr;</span>
          </div>
        </div>
      </div>
    </Link>
  );
}

/* ── Main Dashboard Page ──────────────────────────────────────────────── */
export default function DashboardPage() {
  const user = useAuthStore((s) => s.user);

  const completion = user?.profile_completion_percentage ?? 0;
  const memberSince = user?.date_of_birth ? "Active Member" : "New Member";
  const fitnessGoal = user?.fitness_goal || "Not set yet";

  const tips = [
    { emoji: "🎯", text: "Set a fitness goal to get personalized recommendations" },
    { emoji: "📊", text: "Connect your wearables in Settings to track biometrics" },
    { emoji: "📅", text: "Book your first gym session through Instant Booking" },
  ];

  return (
    <div className="space-y-8 animate-fade-in-up">

      {/* ── Welcome Banner ─────────────────────────────────────────── */}
      <div className="relative rounded-3xl overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-brand-green-dark via-brand-green/80 to-brand-green-light animate-gradient" style={{ backgroundSize: "300% 300%" }} />
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmYiIGZpbGwtb3BhY2l0eT0iMC4wMyI+PHBhdGggZD0iTTM2IDM0djItSDI0di0yaDEyem0wLTRWMjhIMjR2Mmg0djBoOHptLTIuMjg2LTE0TDMwIDEyLjI4NiAyMy43MTQgNiAyMCA5LjcxNCAxNi4yODYgNiAxMCAxMi4yODYgMTMuNzE0IDE2IDEwIDE5LjcxNCAxNi4yODYgMjYgMjAgMjIuMjg2IDIzLjcxNCAyNiAzMCAxOS43MTQgMzMuNzE0IDE2eiIvPjwvZz48L2c+PC9zdmc+')] opacity-30" />
        
        {/* Decorative shapes */}
        <div className="absolute top-0 right-0 w-40 h-40 bg-white/5 rounded-full blur-2xl -mr-10 -mt-10 animate-float" />
        <div className="absolute bottom-0 left-1/3 w-24 h-24 bg-brand-green-dark/30 rounded-full blur-xl animate-float delay-300" />

        <div className="relative z-10 p-8 md:p-10 flex flex-col md:flex-row items-center gap-8">
          <div className="flex-1">
            <h1 className="text-3xl md:text-4xl font-black text-[#131F18] mb-3 leading-tight">
              Welcome back, {user?.first_name || "Athlete"}! 💪
            </h1>
            <p className="text-[#131F18]/70 text-lg font-medium mb-6 max-w-lg">
              {completion < 100
                ? `Your profile is ${completion}% complete. Complete it to unlock personalized coaching and recommendations.`
                : "Your profile is fully set up. You're ready to crush your fitness goals!"
              }
            </p>
            {completion < 100 && (
              <Link href="/dashboard/profile">
                <button className="bg-[#131F18] text-white px-6 py-3 rounded-xl font-bold text-sm hover:bg-[#131F18]/80 hover:shadow-xl hover:scale-[1.03] active:scale-[0.97] transition-all duration-300">
                  Complete Profile &rarr;
                </button>
              </Link>
            )}
          </div>
          <div className="flex-shrink-0">
            <ProgressRing percentage={completion} size={100} strokeWidth={8} />
          </div>
        </div>
      </div>

      {/* ── Stats Grid ─────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-brand-green"><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" /></svg>}
          label="Profile"
          value={`${completion}%`}
          accent="bg-brand-green/15 text-brand-green"
          subtext="Completion"
        />
        <StatCard
          icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-violet-400"><path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" /></svg>}
          label="Role"
          value={user?.role ? user.role.charAt(0).toUpperCase() + user.role.slice(1) : "Member"}
          accent="bg-violet-500/15 text-violet-400"
          subtext="Account Type"
        />
        <StatCard
          icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className={`w-5 h-5 ${user?.email_verified ? 'text-brand-green' : 'text-amber-400'}`}><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" /></svg>}
          label="Email"
          value={user?.email_verified ? "Verified" : "Unverified"}
          accent={user?.email_verified ? "bg-brand-green/15 text-brand-green" : "bg-amber-500/15 text-amber-400"}
          subtext={user?.email_verified ? "Account secured" : "Action needed"}
        />
        <StatCard
          icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-sky-400"><path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" /><path strokeLinecap="round" strokeLinejoin="round" d="M12 18a3.75 3.75 0 00.495-7.467 5.99 5.99 0 00-1.925 3.546 5.974 5.974 0 01-2.133-1A3.75 3.75 0 0012 18z" /></svg>}
          label="Status"
          value={memberSince}
          accent="bg-sky-500/15 text-sky-400"
          subtext={fitnessGoal !== "Not set yet" ? fitnessGoal : "Set a fitness goal"}
        />
      </div>

      {/* ── Quick Actions ──────────────────────────────────────────── */}
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Quick Actions</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <ActionCard
            href="/dashboard/profile"
            title="Edit Profile"
            description="Update your personal information, bio, and fitness goals."
            accentBg="bg-brand-green/15"
            accentBorder="hover:border-brand-green/30"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-6 h-6 text-brand-green"><path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" /></svg>}
          />
          <ActionCard
            href="/dashboard/profile"
            title="Security"
            description="Change your password and manage account security settings."
            accentBg="bg-blue-500/15"
            accentBorder="hover:border-blue-500/30"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-6 h-6 text-blue-400"><path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" /></svg>}
          />
          <ActionCard
            href="/dashboard/profile"
            title="Fitness Goals"
            description={fitnessGoal !== "Not set yet" ? `Current goal: ${fitnessGoal}` : "Define your goals to unlock personalized coaching."}
            accentBg="bg-amber-500/15"
            accentBorder="hover:border-amber-500/30"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-6 h-6 text-amber-400"><path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" /><path strokeLinecap="round" strokeLinejoin="round" d="M12 18a3.75 3.75 0 00.495-7.467 5.99 5.99 0 00-1.925 3.546 5.974 5.974 0 01-2.133-1A3.75 3.75 0 0012 18z" /></svg>}
          />
        </div>
      </div>

      {/* ── Quick Tips ─────────────────────────────────────────────── */}
      <div className="relative bg-surface-elevated/30 backdrop-blur-md rounded-2xl border border-white/5 p-6 overflow-hidden">
        <div className="absolute top-0 right-0 w-48 h-48 bg-brand-green/3 rounded-full blur-3xl -mr-20 -mt-20" />
        
        <h2 className="text-lg font-bold text-white mb-4 relative z-10 flex items-center gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5 text-brand-green">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18" />
          </svg>
          Getting Started
        </h2>
        
        <div className="space-y-3 relative z-10">
          {tips.map((tip, idx) => (
            <div key={idx} className="flex items-start gap-3 p-3 rounded-xl hover:bg-white/3 transition-colors duration-300">
              <span className="text-xl flex-shrink-0 mt-0.5">{tip.emoji}</span>
              <p className="text-sm text-text-muted leading-relaxed">{tip.text}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
