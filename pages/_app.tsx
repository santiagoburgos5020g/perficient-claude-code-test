import '@/styles/globals.css';
import type { AppProps } from 'next/app';
import { Inter } from 'next/font/google';
import { SWRConfig } from 'swr';
import fetcher from '@/lib/fetcher';

const inter = Inter({ subsets: ['latin'] });

export default function App({ Component, pageProps }: AppProps) {
  return (
    <SWRConfig value={{ fetcher, revalidateOnFocus: false }}>
      <main className={inter.className}>
        <Component {...pageProps} />
      </main>
    </SWRConfig>
  );
}
