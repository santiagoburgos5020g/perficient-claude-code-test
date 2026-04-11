import { render, screen } from '@testing-library/react';
import LoadingSpinner from './LoadingSpinner';

describe('LoadingSpinner', () => {
  it('renders the spinner with status role', () => {
    render(<LoadingSpinner />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  it('has accessible label', () => {
    render(<LoadingSpinner />);
    expect(screen.getByLabelText('Loading products')).toBeInTheDocument();
  });

  it('renders in non-centered layout by default', () => {
    const { container } = render(<LoadingSpinner />);
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper).toHaveClass('py-8', 'text-center', 'w-full');
  });

  it('renders in centered layout when centered prop is true', () => {
    const { container } = render(<LoadingSpinner centered />);
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper).toHaveClass('flex', 'justify-center', 'items-center', 'min-h-[50vh]');
  });

  it('renders in non-centered layout when centered prop is false', () => {
    const { container } = render(<LoadingSpinner centered={false} />);
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper).toHaveClass('py-8', 'text-center', 'w-full');
  });
});
