import { clsx, type ClassValue } from "clsx";
import { extendTailwindMerge } from "tailwind-merge";

const twMerge = extendTailwindMerge({});

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}