import { formatDistanceToNowStrict, isYesterday, isToday } from "date-fns";

/**
 * Formats a date string into a highly readable, uppercase format matching the Figma UI.
 * E.g., "2 MIN AGO", "1 HOUR AGO", "YESTERDAY"
 */
export function formatTimeAgo(dateString: string | Date): string {
  const date = new Date(dateString);
  
  if (isYesterday(date)) {
    return "YESTERDAY";
  }

  // Get the distance (e.g., "2 minutes", "1 hour", "3 days")
  const distance = formatDistanceToNowStrict(date);
  
  // Custom replacements to match Figma
  const parts = distance.split(" ");
  if (parts.length >= 2) {
    let [amount, unit] = parts;
    
    // Shorten minutes
    if (unit.startsWith("minute")) {
      unit = "MIN";
    } else if (unit.startsWith("second")) {
      return "JUST NOW";
    }
    
    return `${amount} ${unit} AGO`.toUpperCase();
  }

  return distance.toUpperCase() + " AGO";
}

/**
 * Returns a color (HSL) based on a percentage value:
 * - Green (>= 75%)
 * - Red (< 10%)
 * - Red critical (== 0%)
 * - Smooth transition from Red to Green for values between 10% and 75%
 */
export function getCapacityColor(percentage: number): string {
  if (percentage === 0) return "hsl(0, 100%, 35%)"; // critical red
  if (percentage < 10) return "hsl(0, 100%, 50%)"; // standard red
  if (percentage >= 75) return "hsl(145, 63%, 49%)"; // brand-green (#2ECC70)

  // Smooth transition from red (hue 0) to brand-green (hue 145) for 10% -> 75%
  const fraction = (percentage - 10) / 65;
  const h = 0 + fraction * 145;
  const s = 100 - fraction * 37;
  const l = 50 - fraction * 1;
  return `hsl(${Math.round(h)}, ${Math.round(s)}%, ${Math.round(l)}%)`;
}
