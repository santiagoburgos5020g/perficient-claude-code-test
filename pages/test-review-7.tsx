import { useTodos } from '@/features/todos/hooks/useTodos';
import TodoList from '@/features/todos/components/TodoList';

export default function TestReview7Page() {
  const { todos, isLoading, error } = useTodos();

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Todos</h1>

      {isLoading && (
        <p className="text-gray-500" role="status" aria-busy="true">Loading todos...</p>
      )}

      {error && (
        <p className="text-red-600" role="alert">Error: {error}</p>
      )}

      {!isLoading && !error && <TodoList todos={todos} />}
    </main>
  );
}
