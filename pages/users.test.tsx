import { render, screen } from '@testing-library/react';
import UsersPage from './users';

describe('UsersPage', () => {
  test('renders the building text', () => {
    render(<UsersPage />);
    expect(screen.getByText('Building...')).toBeInTheDocument();
  });
});
