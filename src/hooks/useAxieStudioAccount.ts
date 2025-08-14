import { useState, useEffect } from 'react';
import { useAuth } from './useAuth';

const STORAGE_KEY = 'axie_studio_create_clicked';

export function useAxieStudioAccount() {
  const { user } = useAuth();
  const [hasClickedCreate, setHasClickedCreate] = useState(false);

  // Load the "has clicked create" state from localStorage on mount
  useEffect(() => {
    if (!user) {
      setHasClickedCreate(false);
      return;
    }

    const userStorageKey = `${STORAGE_KEY}_${user.id}`;
    const hasClicked = localStorage.getItem(userStorageKey) === 'true';
    setHasClickedCreate(hasClicked);
  }, [user?.id]);

  // Function to mark that user has clicked create (hides create button forever)
  const markCreateClicked = () => {
    if (!user) return;

    const userStorageKey = `${STORAGE_KEY}_${user.id}`;
    localStorage.setItem(userStorageKey, 'true');
    setHasClickedCreate(true);
    console.log('✅ Create button clicked - will not show again for this user');
  };

  // Show create button only if user hasn't clicked it before
  const showCreateButton = !hasClickedCreate;

  return {
    showCreateButton,
    markCreateClicked
  };
}
