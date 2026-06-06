"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/Button";
import { getPublicPlansApi, SubscriptionPlan } from "@/lib/api";

export const PricingSection = () => {
  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getPublicPlansApi()
      .then((data) => setPlans(data))
      .catch((err) => setError(err.message || "Failed to load plans"))
      .finally(() => setLoading(false));
  }, []);

  const getPeriodLabel = (planType: string) => {
    switch (planType) {
      case "monthly": return "/ mo";
      case "annual": return "/ yr";
      case "per_session": return "/ session";
      case "free_trial": return "/ trial";
      default: return "";
    }
  };

  return (
    <section id="pricing" className="w-full py-24 px-6 bg-[#0F172A]/20 relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(46,204,112,0.04)_0%,transparent_70%)] pointer-events-none" />

      <div className="max-w-6xl mx-auto flex flex-col items-center relative z-10">
        <h2 className="text-3xl md:text-5xl font-bold text-center text-white mb-16 uppercase animate-fade-in-up">
          CHOOSE YOUR <span className="text-transparent bg-clip-text bg-gradient-to-r from-brand-green to-brand-green-light">TIER</span>
        </h2>

        {loading && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 w-full items-center">
            {[1, 2, 3].map((i) => (
              <div key={i} className="bg-card-dark rounded-[32px] p-8 border border-white/5 animate-pulse h-[400px]" />
            ))}
          </div>
        )}

        {error && (
          <p className="text-red-400 text-center">{error}</p>
        )}

        {!loading && !error && plans.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 w-full items-center">
            {plans.map((plan, idx) => (
              <div
                key={plan.id}
                className={`relative bg-card-dark rounded-[32px] p-8 flex flex-col h-full border transition-all duration-500 hover:-translate-y-2 hover:shadow-xl animate-fade-in-up ${plan.is_featured
                    ? "border-brand-green/40 shadow-[0_0_40px_rgba(46,204,112,0.12)] transform md:-translate-y-4 animate-border-glow hover:shadow-[0_0_50px_rgba(46,204,112,0.2)]"
                    : "border-white/5 hover:border-brand-green/20 hover:shadow-brand-green/10"
                  }`}
                style={{ animationDelay: `${(idx + 1) * 150}ms` }}
              >
                {plan.is_featured && (
                  <div className="absolute -top-4 left-1/2 -translate-x-1/2 text-[#131F18] text-xs font-bold tracking-widest px-4 py-1.5 rounded-full uppercase animate-shimmer bg-gradient-to-r from-brand-green via-brand-green-light to-brand-green" style={{ backgroundSize: "200% auto" }}>
                    MOST POPULAR
                  </div>
                )}

                <h3 className="text-2xl font-bold text-white mb-2">{plan.name}</h3>
                <div className="flex items-baseline gap-1 mb-4">
                  <span className="text-4xl font-bold text-white">${Math.round(parseFloat(plan.price))}</span>
                  <span className="text-text-muted">{getPeriodLabel(plan.plan_type)}</span>
                </div>
                <p className="text-text-muted text-sm mb-8">{plan.description}</p>

                <ul className="space-y-4 mb-8 flex-grow">
                  {(plan.features ?? []).map((feature, fIdx) => (
                    <li key={fIdx} className="flex items-center gap-3 text-sm text-white">
                      <span className="text-brand-green flex-shrink-0 w-5 h-5 rounded-full bg-brand-green/20 flex items-center justify-center text-xs">✓</span>
                      {feature}
                    </li>
                  ))}
                </ul>

                <Button
                  variant={plan.is_featured ? "primary" : "outline"}
                  className={`w-full uppercase ${plan.is_featured ? "animate-pulse-glow" : ""}`}
                >
                  {plan.is_featured ? `UPGRADE TO ${plan.name.toUpperCase()}` : `SELECT ${plan.name.toUpperCase()}`}
                </Button>
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  );
};
