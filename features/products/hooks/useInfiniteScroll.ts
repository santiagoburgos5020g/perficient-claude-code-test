import { useState, useEffect, useRef, useCallback } from 'react';
import type { Product } from '@/features/products/types/product';
import type { ApiEnvelope } from '@/lib/api-handler';

export function useInfiniteScroll() {
  const [products, setProducts] = useState<Product[]>([]);
  const [page, setPage] = useState(1);
  const [isLoading, setIsLoading] = useState(false);
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const loadingRef = useRef(false);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const observerRef = useRef<IntersectionObserver | null>(null);
  const pageRef = useRef(page);

  pageRef.current = page;

  const fetchProducts = useCallback(async () => {
    if (loadingRef.current) return;

    loadingRef.current = true;
    setIsLoading(true);
    setError(null);

    try {
      const currentPage = pageRef.current;
      const response = await fetch(`/api/products?page=${currentPage}&limit=30`);

      if (!response.ok) {
        throw new Error(`HTTP error ${response.status}`);
      }

      const envelope: ApiEnvelope<{ products: Product[] }> = await response.json();

      setProducts((prev) => [...prev, ...(envelope.data?.products ?? [])]);
      setHasMore((envelope.meta as { hasMore?: boolean })?.hasMore ?? false);
      setPage((prev) => prev + 1);

      if (currentPage === 1) {
        setIsInitialLoading(false);
      }
    } catch {
      const currentPage = pageRef.current;
      if (currentPage === 1) {
        setError('Failed to load products. Please try again.');
        setIsInitialLoading(false);
      } else {
        setError('Failed to load more products.');
      }
    } finally {
      loadingRef.current = false;
      setIsLoading(false);
    }
  }, []);

  const retry = useCallback(() => {
    fetchProducts();
  }, [fetchProducts]);

  // Set up IntersectionObserver
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
        if (entries[0].isIntersecting && !loadingRef.current) {
          fetchProducts();
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
  }, [hasMore, fetchProducts, page]);

  return {
    products,
    isLoading,
    isInitialLoading,
    error,
    hasMore,
    sentinelRef,
    retry,
  };
}
