import { useTodos } from '@/hooks/useTodos';
import TodoList from '@/components/TodoList/TodoList';


export default function TestReview7Page() {
  const { todos, isLoading, error } = useTodos();
  const jaja: any = 1;
  return (
    <main className="bg-white min-h-screen w-full p-8">
      <>
        <h1 className="text-2xl font-bold text-perficient-dark mb-6">Todos</h1>
        <h2>{jaja}</h2>
      </>
      

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
