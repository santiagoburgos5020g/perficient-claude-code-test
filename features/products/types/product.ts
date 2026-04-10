export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  image: string;
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

export interface ProductsApiResponse {
  products: Product[];
  pagination: PaginationMeta;
}

export interface ProductsApiError {
  error: string;
  message: string;
}
