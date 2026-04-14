import { render, screen, fireEvent } from '@testing-library/react';
import ProductCard from './ProductCard';
import type { Product } from '@/features/products/types/product';


// test

jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}));

const mockProduct: Product = {
  id: 1,
  name: 'Test Product',
  description: 'Test Description',
  price: 99.99,
  image: '/test-image.jpg',
};

describe('ProductCard - Add To Cart Button', () => {
  it('renders Add To Cart button with exact text', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveTextContent('Add To Cart');
  });

  it('button has correct styling classes', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveClass(
      'w-full',
      'bg-perficient-teal',
      'text-white',
      'text-sm',
      'font-normal',
      'py-3',
      'mt-auto',
      'rounded-none',
      'cursor-default'
    );
  });

  it('button is the last child element within the article', () => {
    render(<ProductCard product={mockProduct} />);
    const article = screen.getByRole('article');
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(article.lastElementChild).toBe(button);
  });

  it('button click does not throw an error', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(() => fireEvent.click(button)).not.toThrow();
  });

  it('button has aria-label containing the product name', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveAttribute('aria-label', 'Add Test Product to cart');
  });

  it('button has type="button"', () => {
    render(<ProductCard product={mockProduct} />);
    const button = screen.getByRole('button', { name: /add test product to cart/i });
    expect(button).toHaveAttribute('type', 'button');
  });

  it('article uses flex column layout for button pinning', () => {
    render(<ProductCard product={mockProduct} />);
    const article = screen.getByRole('article');
    expect(article).toHaveClass('flex', 'flex-col');
  });

  it('renders button correctly when image fails to load', () => {
    render(<ProductCard product={mockProduct} />);
    const img = screen.getByAltText('Test Product');
    fireEvent.error(img);
    expect(screen.getByText('No image')).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /add test product to cart/i })
    ).toBeInTheDocument();
  });

  it('preserves existing product card rendering', () => {
    render(<ProductCard product={mockProduct} />);
    expect(screen.getByText('Test Product')).toBeInTheDocument();
    expect(screen.getByText('Test Description')).toBeInTheDocument();
    expect(screen.getByText('$99.99')).toBeInTheDocument();
    expect(screen.getByAltText('Test Product')).toBeInTheDocument();
  });
});
