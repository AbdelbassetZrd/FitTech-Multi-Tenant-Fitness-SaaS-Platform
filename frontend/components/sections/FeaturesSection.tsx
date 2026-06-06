export const FeaturesSection = () => {
  const features = [
    {
      title: "INSTANT BOOKING",
      description: "Secure your spot at any partner gym or book a personal session in real-time. Sync directly with your Apple or Google Calendar.",
      icon: "📅",
    },
    {
      title: "LIVE STATS",
      description: "Connect wearables for biometric tracking. Monitor recovery, power output, and metabolic efficiency.",
      icon: "📊",
    },
    {
      title: "CONNECTED GEAR",
      description: "Upgrade your arsenal with professional gear. Verified by elite trainers. Exclusive drops and subscription nutrition plans.",
      icon: "🏋️",
    },
  ];

  return (
    <section id="features" className="w-full py-24 px-6 bg-bg-main relative overflow-hidden">
      {/* Subtle background decoration */}
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_50%,rgba(46,204,112,0.03)_0%,transparent_50%)] pointer-events-none" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_80%_80%,rgba(46,204,112,0.02)_0%,transparent_50%)] pointer-events-none" />

      <div className="max-w-6xl mx-auto flex flex-col items-center relative z-10">
        <h2 className="text-3xl md:text-5xl font-bold text-center text-white mb-16 uppercase animate-fade-in-up">
          MASTER YOUR <span className="text-transparent bg-clip-text bg-gradient-to-r from-brand-green to-brand-green-light">EC3 SYSTEM</span>
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 w-full">
          {features.map((feature, idx) => (
            <div 
              key={idx} 
              className={`group bg-card-dark rounded-[32px] p-8 transition-all duration-500 hover:-translate-y-3 hover:shadow-2xl hover:shadow-brand-green/10 border border-white/5 hover:border-brand-green/20 animate-fade-in-up`}
              style={{ animationDelay: `${(idx + 1) * 150}ms` }}
            >
              <div className="w-14 h-14 rounded-2xl bg-brand-green/20 text-brand-green text-3xl flex items-center justify-center mb-6 transition-all duration-500 group-hover:bg-brand-green/30 group-hover:shadow-lg group-hover:shadow-brand-green/20 group-hover:scale-110">
                {feature.icon}
              </div>
              <h3 className="text-2xl font-bold text-white mb-4 uppercase">{feature.title}</h3>
              <p className="text-text-muted leading-relaxed mb-6">
                {feature.description}
              </p>
              <button className="text-brand-green font-bold text-sm tracking-widest uppercase flex items-center gap-2 group-hover:gap-4 transition-all duration-300">
                LEARN MORE <span aria-hidden="true" className="transition-transform duration-300 group-hover:translate-x-1 group-hover:scale-125">&rarr;</span>
              </button>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
