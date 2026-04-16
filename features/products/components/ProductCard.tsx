import { useState } from 'react';
import Image from 'next/image';
import type { Product } from '@/features/products/types/product';
import { formatPrice } from '@/features/products/utils/formatPrice';

interface ProductCardProps {
  product: Product | null;
}

export default function ProductCard({ product }: ProductCardProps) {
  const [imgError, setImgError] = useState(false);

  return (
    <article className="bg-white shadow-md hover:shadow-xl rounded-none p-4 transition-shadow duration-200 flex flex-col">
      <div className="aspect-square overflow-hidden relative mb-3">
        {imgError ? (
          <div className="bg-gray-200 w-full h-full flex items-center justify-center">
            <span className="text-gray-400 text-sm">No image</span>
          </div>
        ) : (
          <Image
            src={product.image}
            alt={product.name}
            width={400}
            height={400}
            className="object-cover w-full h-full"
            onError={() => setImgError(true)}
          />
        )}
      </div>
      <h2 className="font-bold text-base text-perficient-dark">{product.name}</h2>
      <p className="font-normal text-sm text-perficient-dark/70 mt-1">{product.description}</p>
      <p className="font-bold text-base text-perficient-dark mt-2">{formatPrice(product.price)}</p>
      <button
        type="button"
        className="w-full bg-perficient-teal text-white text-sm font-normal py-3 mt-auto rounded-none cursor-default"
        onClick={() => {}}
        aria-label={`Add ${product.name} to cart`}
      >
        Add To Cart
      </button>
    </article>
  );
}
