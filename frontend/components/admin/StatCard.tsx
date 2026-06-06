interface StatCardProps {
  label: string;
  value: string;
  icon?: React.ReactNode;
  change?: string;
  changeType?: "up" | "down" | "neutral";
  subtitle?: React.ReactNode;
  extra?: React.ReactNode;
  valueColor?: string;
  valueStyle?: React.CSSProperties;
  onClick?: () => void;
  isActive?: boolean;
}

export default function StatCard({
  label,
  value,
  icon,
  change,
  changeType = "up",
  subtitle,
  extra,
  valueColor = "text-white",
  valueStyle,
  onClick,
  isActive = false,
}: StatCardProps) {
  const changeColor =
    changeType === "up"
      ? "text-brand-green"
      : changeType === "down"
      ? "text-red-400"
      : "text-text-muted";

  return (
    <div 
      onClick={onClick}
      className={`bg-[#111827]/80 border ${isActive ? 'border-brand-green bg-brand-green/5' : 'border-white/5'} rounded-2xl p-5 transition-all duration-500 hover:border-white/10 hover:-translate-y-0.5 group ${onClick ? 'cursor-pointer' : ''}`}
    >
      <div className="flex items-start justify-between mb-1">
        <p className="text-[10px] font-bold tracking-[0.15em] text-text-muted/60 uppercase">{label}</p>
        {icon && (
          <div className="text-text-muted/40 group-hover:text-text-muted/70 transition-colors">
            {icon}
          </div>
        )}
      </div>
      <div className="flex items-end justify-between">
        <div>
          <p className={`text-3xl font-black mt-1 ${valueColor}`} style={valueStyle}>{value}</p>
          {subtitle && <p className="text-xs text-text-muted mt-1">{subtitle}</p>}
        </div>
        <div className="flex flex-col items-end gap-1">
          {change && (
            <span className={`text-xs font-semibold flex items-center gap-1 ${changeColor}`}>
              {changeType === "up" && (
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-3 h-3">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" />
                </svg>
              )}
              {changeType === "down" && (
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-3 h-3">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 6L9 12.75l4.286-4.286a11.948 11.948 0 014.306 6.43l.776 2.898m0 0l3.182-5.511m-3.182 5.51l-5.511-3.181" />
                </svg>
              )}
              {change}
            </span>
          )}
          {extra}
        </div>
      </div>
    </div>
  );
}
