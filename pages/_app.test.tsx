import { render, screen } from '@testing-library/react';
import App from './_app';
import type { AppProps } from 'next/app';

jest.mock('next/font/google', () => ({
  Inter: () => ({ className: 'inter-mock' }),
}));

describe('App', () => {
  function MockComponent() {
    return <div>Mock Page</div>;
  }

  const defaultProps: AppProps = {
    Component: MockComponent,
    pageProps: {},
    router: {} as any,
  };

  it('renders the page component inside a main element', () => {
    render(<App {...defaultProps} />);
    expect(screen.getByRole('main')).toBeInTheDocument();
    expect(screen.getByText('Mock Page')).toBeInTheDocument();
  });

  it('applies the Inter font class to main', () => {
    render(<App {...defaultProps} />);
    expect(screen.getByRole('main')).toHaveClass('inter-mock');
  });

  it('passes pageProps to the component', () => {
    function PropsComponent({ title }: { title: string }) {
      return <div>{title}</div>;
    }
    render(
      <App
        {...defaultProps}
        Component={PropsComponent as any}
        pageProps={{ title: 'Hello' }}
      />
    );
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });
});
