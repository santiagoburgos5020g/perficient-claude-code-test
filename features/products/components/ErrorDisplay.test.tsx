import { render, screen, fireEvent } from '@testing-library/react';
import ErrorDisplay from './ErrorDisplay';

describe('ErrorDisplay', () => {
  const mockRetry = jest.fn();

  beforeEach(() => {
    mockRetry.mockClear();
  });

  it('renders the error message', () => {
    render(<ErrorDisplay message="Something went wrong" onRetry={mockRetry} />);
    expect(screen.getByText('Something went wrong')).toBeInTheDocument();
  });

  it('renders a Retry button', () => {
    render(<ErrorDisplay message="Error" onRetry={mockRetry} />);
    const button = screen.getByRole('button', { name: /retry/i });
    expect(button).toBeInTheDocument();
  });

  it('calls onRetry when Retry button is clicked', () => {
    render(<ErrorDisplay message="Error" onRetry={mockRetry} />);
    fireEvent.click(screen.getByRole('button', { name: /retry/i }));
    expect(mockRetry).toHaveBeenCalledTimes(1);
  });
});
