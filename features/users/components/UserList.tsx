import type { User } from '@/features/users/types/user';

interface UserListProps {
  users: User[];
}

export default function UserList({ users }: UserListProps) {
  return (
    <ul className="space-y-4">
      {users.map((user) => (
        <li
          key={user.id}
          className="border border-gray-200 rounded p-4"
        >
          <p className="font-bold text-perficient-dark">{user.name}</p>
          <p className="text-sm text-perficient-dark/70">@{user.username}</p>
          <p className="text-sm text-perficient-dark/70">{user.email}</p>
          <p className="text-sm text-perficient-dark/70">{user.phone}</p>
          <p className="text-sm text-perficient-dark/70">{user.company.name}</p>
        </li>
      ))}
    </ul>
  );
}
