import { render, screen } from '@testing-library/react';
import Home from './index';
import { useInfiniteScroll } from '@/features/products/hooks/useInfiniteScroll';
import React from 'react';

//test

jest.mock('next/image', () => ({
  __esModule: true,
  default: (props: any) => <img {...props} />,
}));

jest.mock('@/features/products/hooks/useInfiniteScroll');

const mockUseInfiniteScroll = useInfiniteScroll as jest.MockedFunction<
  typeof useInfiniteScroll
>;

function createMockReturn(overrides: Partial<ReturnType<typeof useInfiniteScroll>> = {}) {
  return {
    products: [],
    isLoading: false,
    isInitialLoading: false,
    error: null,
    hasMore: false,
    sentinelRef: { current: null } as React.RefObject<HTMLDivElement>,
    retry: jest.fn(),
    ...overrides,
  };
}

describe('Home page', () => {
  it('shows loading spinner during initial load', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({ isInitialLoading: true })
    );
    render(<Home />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  it('shows error with retry when initial load fails', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({ error: 'Failed to load products. Please try again.' })
    );
    render(<Home />);
    expect(screen.getByText('Failed to load products. Please try again.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument();
  });

  it('renders product grid when products are loaded', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({
        products: [
          { id: 1, name: 'Widget', description: 'A widget', price: 9.99, image: '/w.jpg' },
        ],
      })
    );
    render(<Home />);
    expect(screen.getByText('Widget')).toBeInTheDocument();
  });

  it('shows non-centered loading spinner when loading more products', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({
        products: [
          { id: 1, name: 'Widget', description: 'A widget', price: 9.99, image: '/w.jpg' },
        ],
        isLoading: true,
      })
    );
    render(<Home />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  it('shows inline error when loading more products fails', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({
        products: [
          { id: 1, name: 'Widget', description: 'A widget', price: 9.99, image: '/w.jpg' },
        ],
        error: 'Failed to load more products.',
      })
    );
    render(<Home />);
    expect(screen.getByText('Failed to load more products.')).toBeInTheDocument();
  });

  it('shows end-of-catalog message when no more products', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({
        products: [
          { id: 1, name: 'Widget', description: 'A widget', price: 9.99, image: '/w.jpg' },
        ],
        hasMore: false,
      })
    );
    render(<Home />);
    expect(screen.getByText("You've reached the end of the catalog")).toBeInTheDocument();
  });

  it('renders sentinel div when there are more products', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({ hasMore: true })
    );
    const { container } = render(<Home />);
    const sentinel = container.querySelector('.h-4');
    expect(sentinel).toBeInTheDocument();
  });

  it('does not show end-of-catalog when products list is empty', () => {
    mockUseInfiniteScroll.mockReturnValue(
      createMockReturn({ products: [], hasMore: false })
    );
    render(<Home />);
    expect(screen.queryByText("You've reached the end of the catalog")).not.toBeInTheDocument();
  });
});
