/** @type {import('next').NextConfig} */
const nextConfig = {
  // Environment variables
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },

  // Public runtime config (deprecated, use env instead)
  publicRuntimeConfig: {
    apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api',
    siteUrl: process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000',
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
    domains: ['localhost', 'expo.timuroki.ink'],
    formats: ['image/webp', 'image/avif'],
  },

  // Compression
  compress: true,

  // Output configuration
  output: process.env.NODE_ENV === 'production' ? 'standalone' : undefined,

  // Transpile shared packages (if using workspace)
  transpilePackages: ['@quotes/shared'],

  // Webpack configuration
  webpack: (config, { buildId, dev, isServer, defaultLoaders, webpack }) => {
    // Add shared module resolution
    config.resolve.alias['@shared'] = require('path').resolve(__dirname, '../shared');
    
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
    if (process.env.NODE_ENV === 'development') {
      return [
        {
          source: '/api/:path*',
          destination: `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api'}/:path*`,
        },
      ];
    }
    return [];
  },

  // Headers
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
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
    dirs: ['pages', 'components', 'lib'],
  },

  // TypeScript configuration
  typescript: {
    ignoreBuildErrors: false,
  },
};

module.exports = nextConfig;