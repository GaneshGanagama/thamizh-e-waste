import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyBXtphQabzIyG_hw617jPZktk71tUOVfwE",
  authDomain: "thamizh-faf1a.firebaseapp.com",
  projectId: "thamizh-faf1a",
  storageBucket: "thamizh-faf1a.appspot.com", // ✅ Corrected
  messagingSenderId: "419123520013",
  appId: "1:419123520013:web:77f6a0aaa131c0d5e72b44"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
