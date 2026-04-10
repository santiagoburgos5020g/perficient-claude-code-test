interface LoadingSpinnerProps {
  centered?: boolean;
}

export default function LoadingSpinner({ centered }: LoadingSpinnerProps) {
  const spinner = (
    <div
      role="status"
      aria-label="Loading products"
      className="inline-block h-10 w-10 border-4 border-perficient-blue border-t-transparent rounded-full animate-spin"
    />
  );

  if (centered) {
    return (
      <div className="flex justify-center items-center min-h-[50vh]">
        {spinner}
      </div>
    );
  }

  return (
    <div className="py-8 text-center w-full">
      {spinner}
    </div>
  );
}
