interface ErrorDisplayProps {
  message: string;
  onRetry: () => void;
}
// abc
export default function ErrorDisplay({ message, onRetry }: ErrorDisplayProps) {
  return (
    <div className="flex flex-col items-center gap-4 py-8">
      <p className="text-red-600 text-sm">{message}</p>
      <button
        onClick={onRetry}
        className="bg-perficient-blue text-white font-semibold uppercase rounded-none px-6 py-3 hover:bg-opacity-90 transition"
      >
        Retry
      </button>
    </div>
  );
}
