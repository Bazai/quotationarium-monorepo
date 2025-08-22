// Environment-based configuration
export const API_URL: string = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/";
export const SITE_URL: string = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
export const GOOGLE_TAG_ID: string = process.env.NEXT_PUBLIC_GOOGLE_TAG_ID || "GTM-5KMHZSHX";

// Deprecated - kept for backward compatibility
export const URL: string = SITE_URL;

// Development helpers
export const IS_DEVELOPMENT = process.env.NODE_ENV === 'development';
export const IS_PRODUCTION = process.env.NODE_ENV === 'production';