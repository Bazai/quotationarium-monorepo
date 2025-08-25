/** @type {import('next').NextConfig} */
const nextConfig = {
  // Environment variables
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },

  // Public runtime config (deprecated, use env instead)
  publicRuntimeConfig: {
    apiUrl: process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api",
    siteUrl: process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
  },

  // Server runtime config
  serverRuntimeConfig: {
    // Will only be available on the server side
  },

  // Experimental features
  experimental: {
    // Enable if using shared TypeScript configuration
    externalDir: true,
  },

  // Asset optimization
  images: {
    domains: ["localhost", "expo.timuroki.ink"],
    formats: ["image/webp", "image/avif"],
  },

  // Compression
  compress: true,

  // Output configuration
  output: process.env.NODE_ENV === "production" ? "standalone" : undefined,

  // Webpack configuration
  webpack(config) {
    // Grab the existing rule that handles SVG imports
    const fileLoaderRule = config.module.rules.find((rule) =>
      rule.test?.test?.(".svg")
    );

    config.module.rules.push(
      // Reapply the existing rule, but only for svg imports ending in ?url
      {
        ...fileLoaderRule,
        test: /\.svg$/i,
        resourceQuery: /url/, // *.svg?url
      },
      // Convert all other *.svg imports to React components
      {
        test: /\.svg$/i,
        issuer: fileLoaderRule.issuer,
        resourceQuery: { not: [...fileLoaderRule.resourceQuery.not, /url/] }, // exclude if *.svg?url
        use: ["@svgr/webpack"],
      }
    );

    // Modify the file loader rule to ignore *.svg, since we have it handled now.
    fileLoaderRule.exclude = /\.svg$/i;

    return config;
  },

  // Redirects
  async redirects() {
    return [
      // Add any redirects here
    ];
  },

  // Rewrites (for API proxying in development)
  async rewrites() {
    if (process.env.NODE_ENV === "development") {
      return [
        {
          source: "/api/:path*",
          destination: `${
            process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api"
          }/:path*`,
        },
      ];
    }
    return [];
  },

  // Headers
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
        ],
      },
    ];
  },

  // React strict mode
  reactStrictMode: true,

  // SWC minification
  swcMinify: true,

  // ESLint configuration
  eslint: {
    dirs: ["pages", "components", "lib"],
  },

  // TypeScript configuration
  typescript: {
    ignoreBuildErrors: false,
  },
};

module.exports = nextConfig;
