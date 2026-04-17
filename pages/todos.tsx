import { useTodos } from '@/features/todos/hooks/useTodos';
import TodoList from '@/features/todos/components/TodoList';
import LoadingSpinner from '@/features/products/components/LoadingSpinner';
import ErrorDisplay from '@/features/products/components/ErrorDisplay';

export default function TodosPage() {
  const { todos, isLoading, error, mutate } = useTodos();

  if (isLoading) {
    return <LoadingSpinner centered />;
  }

  if (error) {
    return (
      <div className="flex justify-center items-center min-h-[50vh]" role="alert">
        <ErrorDisplay message={error} onRetry={() => mutate()} />
      </div>
    );
  }

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold mb-6">Todos ({todos.length})</h1>
      <TodoList todos={todos} />
    </main>
  );
}
