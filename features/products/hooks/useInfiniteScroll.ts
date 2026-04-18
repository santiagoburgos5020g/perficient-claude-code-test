import { useEffect, useRef, useCallback } from 'react';
import useSWRInfinite from 'swr/infinite';
import type { Product } from '@/features/products/types/product';
import type { ApiEnvelope } from '@/lib/api-handler';

type ProductsEnvelope = ApiEnvelope<{ products: Product[] }>;

interface UseInfiniteScrollReturn {
  products: Product[];
  isLoading: boolean;
  isInitialLoading: boolean;
  error: string | null;
  hasMore: boolean;
  sentinelRef: React.RefObject<HTMLDivElement>;
  retry: () => void;
}

const PAGE_LIMIT = 30;

function getKey(pageIndex: number, previousPageData: ProductsEnvelope | null): string | null {
  if (previousPageData && !(previousPageData.meta as { hasMore?: boolean })?.hasMore) {
    return null;
  }
  return `/api/products?page=${pageIndex + 1}&limit=${PAGE_LIMIT}`;
}

export function useInfiniteScroll(): UseInfiniteScrollReturn {
  const { data, error, size, setSize, isLoading, isValidating, mutate } =
    useSWRInfinite<ProductsEnvelope>(getKey);

  const sentinelRef = useRef<HTMLDivElement>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);

  const products = data
    ? data.flatMap((envelope) => envelope.data?.products ?? [])
    : [];

  const hasMore = data
    ? (data[data.length - 1]?.meta as { hasMore?: boolean })?.hasMore ?? false
    : true;

  const isInitialLoading = !data && !error;
  const isLoadingMore = isLoading || (size > 0 && data && typeof data[size - 1] === 'undefined');

  const loadMore = useCallback(() => {
    if (!isValidating && hasMore) {
      setSize((s) => s + 1);
    }
  }, [isValidating, hasMore, setSize]);

  const retry = useCallback(() => {
    mutate();
  }, [mutate]);

  useEffect(() => {
    if (!hasMore) {
      if (observerRef.current) {
        observerRef.current.disconnect();
        observerRef.current = null;
      }
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          loadMore();
        }
      },
      { threshold: 0.1 }
    );

    observerRef.current = observer;

    if (sentinelRef.current) {
      observer.observe(sentinelRef.current);
    }

    return () => {
      observer.disconnect();
    };
  }, [hasMore, loadMore]);

  return {
    products,
    isLoading: isLoadingMore ?? false,
    isInitialLoading,
    error: error ? (error as Error).message : null,
    hasMore,
    sentinelRef,
    retry,
  };
}
