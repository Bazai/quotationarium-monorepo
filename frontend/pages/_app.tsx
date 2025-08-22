import Head from "next/head";
import Script from "next/script";
import "../styles/global.css";

import React from "react";
import { AppProps } from "next/app";
import { NuqsAdapter } from "nuqs/adapters/next/pages";
import { GOOGLE_TAG_ID } from "../lib/constants";

export default function App({ Component, pageProps }: AppProps) {
  return (
    <NuqsAdapter>
      <Head>
        <meta name="viewport" content="viewport-fit=cover" />
      </Head>
      <Script id="gtm" strategy="afterInteractive">
        {`
        (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
        new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
        j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
        'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
        })(window,document,'script','dataLayer','${GOOGLE_TAG_ID}');
      `}
      </Script>
      <Component {...pageProps} />
    </NuqsAdapter>
  );
}