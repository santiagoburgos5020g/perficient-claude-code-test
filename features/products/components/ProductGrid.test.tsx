import { render, screen } from '@testing-library/react';
import ProductGrid from './ProductGrid';

jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}));

describe('ProductGrid', () => {
  const mockProducts = [
    { id: 1, name: 'Product A', description: 'Desc A', price: 10.0, image: '/a.jpg' },
    { id: 2, name: 'Product B', description: 'Desc B', price: 20.0, image: '/b.jpg' },
  ];

  it('renders a section with "Product catalog" label', () => {
    render(<ProductGrid products={mockProducts} />);
    expect(screen.getByLabelText('Product catalog')).toBeInTheDocument();
  });

  it('renders a ProductCard for each product', () => {
    render(<ProductGrid products={mockProducts} />);
    expect(screen.getByText('Product A')).toBeInTheDocument();
    expect(screen.getByText('Product B')).toBeInTheDocument();
  });

  it('renders the grid container with responsive classes', () => {
    render(<ProductGrid products={mockProducts} />);
    const section = screen.getByLabelText('Product catalog');
    const grid = section.firstChild as HTMLElement;
    expect(grid).toHaveClass('grid', 'grid-cols-1', 'gap-4');
  });

  it('renders empty grid when no products provided', () => {
    render(<ProductGrid products={[]} />);
    const section = screen.getByLabelText('Product catalog');
    const grid = section.firstChild as HTMLElement;
    expect(grid.children).toHaveLength(0);
  });
});
