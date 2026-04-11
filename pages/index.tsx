import { useInfiniteScroll } from '@/features/products/hooks/useInfiniteScroll';
import ProductGrid from '@/features/products/components/ProductGrid';
import LoadingSpinner from '@/features/products/components/LoadingSpinner';
import ErrorDisplay from '@/features/products/components/ErrorDisplay';

export default function Home() {
  const { products, isLoading, isInitialLoading, error, hasMore, sentinelRef, retry } =
    useInfiniteScroll();

  return (
    <div className="bg-white min-h-screen w-full">
      {isInitialLoading && <LoadingSpinner centered />}

      {error && products.length === 0 && !isInitialLoading && (
        <div className="flex justify-center items-center min-h-[50vh]">

        </div>
      )}

      {products.length > 0 && <ProductGrid products={products} />}

      {isLoading && !isInitialLoading && <LoadingSpinner />}

      {error && products.length > 0 && (
        <ErrorDisplay message={error} onRetry={retry} />
      )}

      {!hasMore && products.length > 0 && (
        <p className="text-sm text-gray-400 text-center py-8">
          You&apos;ve reached the end of the catalog
        </p>
      )}

      {hasMore && <div ref={sentinelRef} className="h-4" />}
    </div>
  );
}
