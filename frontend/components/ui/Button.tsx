import { ButtonHTMLAttributes, forwardRef } from "react";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "auth" | "outline" | "social";
  size?: "default" | "sm" | "lg";
  isLoading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className = "", variant = "primary", size = "default", isLoading, children, disabled, ...props }, ref) => {
    const baseStyles =
      "inline-flex items-center justify-center font-bold tracking-wide transition-all duration-300 ease-out focus:outline-none focus:ring-2 focus:ring-brand-green focus:ring-offset-2 focus:ring-offset-bg-main disabled:opacity-50 disabled:pointer-events-none active:scale-[0.97]";

    let variantStyles = "";
    switch (variant) {
      case "primary":
        variantStyles = "bg-brand-green text-[#131F18] hover:bg-brand-green-light hover:shadow-lg hover:shadow-brand-green/25 hover:scale-[1.02]";
        break;
      case "auth":
        variantStyles = "bg-auth-green text-white hover:bg-green-600 hover:shadow-lg hover:shadow-auth-green/25 hover:scale-[1.02]";
        break;
      case "outline":
        variantStyles =
          "bg-transparent border border-white/60 text-white hover:bg-white/10 hover:border-brand-green/50 hover:shadow-md hover:shadow-brand-green/10";
        break;
      case "social":
        variantStyles =
          "bg-white border border-border-light text-[#1E293B] hover:bg-gray-50 hover:shadow-md font-semibold";
        break;
    }

    let sizeStyles = "";
    switch (size) {
      case "default":
        sizeStyles = "h-12 px-6 py-3 rounded-xl";
        break;
      case "sm":
        sizeStyles = "h-10 px-4 py-2 rounded-lg text-sm";
        break;
      case "lg":
        sizeStyles = "h-14 px-8 py-4 rounded-2xl text-lg";
        break;
    }

    return (
      <button
        ref={ref}
        className={`${baseStyles} ${variantStyles} ${sizeStyles} ${className}`}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading ? (
          <svg
            suppressHydrationWarning
            className="animate-spin h-5 w-5"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              suppressHydrationWarning
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              suppressHydrationWarning
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
        ) : (
          children
        )}
      </button>
    );
  }
);

Button.displayName = "Button";
