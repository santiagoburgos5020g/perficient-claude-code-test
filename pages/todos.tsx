import { useTodos } from '@/features/todos/hooks/useTodos';
import TodoList from '@/features/todos/components/TodoList';

export default function TodosPage() {
  const { todos, isLoading, error } = useTodos();

  return (
    <main className="p-4">
      <h1 className="text-2xl font-bold mb-4">Todos</h1>

      {isLoading && (
        <p role="status" className="text-gray-500">Loading...</p>
      )}

      {error && (
        <p role="alert" className="text-red-500">Error: {error}</p>
      )}

      {!isLoading && !error && <TodoList todos={todos} />}
    </main>
  );
}
