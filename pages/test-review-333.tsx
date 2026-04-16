import { useUsers } from '@/features/users/hooks/useUsers';
import UserList from '@/features/users/components/UserList';

export default function TestReview333Page() {
  const { users, isLoading, error } = useUsers();

  return (
    <main className="bg-white min-h-screen w-full p-8">
      <h1 className="text-2xl font-bold text-perficient-dark mb-6">Hello 123</h1>

      {isLoading && (
        <p className="text-gray-500" role="status" aria-busy="true">Loading users...</p>
      )}

      {error && (
        <p className="text-red-600" role="alert">Error: {error}</p>
      )}

      {!isLoading && !error && <UserList users={users} />}
    </main>
  );
}
