import { render, screen } from '@testing-library/react';
import OrdersPage from './orders';

describe('OrdersPage', () => {
  test('renders the building text', () => {
    render(<OrdersPage />);
    expect(screen.getByText('Building...')).toBeInTheDocument();
  });
});
