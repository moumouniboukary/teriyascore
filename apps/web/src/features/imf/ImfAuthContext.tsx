import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import {
  partnerRequest,
  partnerStorage,
  type PartnerImfInfo,
} from "./partnerApi";

type ImfAuthState = {
  key: string | null;
  imf: PartnerImfInfo | null;
  login: (apiKey: string) => Promise<void>;
  logout: () => void;
};

const ImfAuthContext = createContext<ImfAuthState | null>(null);

export function ImfAuthProvider({ children }: { children: ReactNode }) {
  const [key, setKey] = useState<string | null>(() => partnerStorage.getKey());
  const [imf, setImf] = useState<PartnerImfInfo | null>(() =>
    partnerStorage.getImf()
  );

  const value = useMemo<ImfAuthState>(
    () => ({
      key,
      imf,
      async login(apiKey: string) {
        partnerStorage.setKey(apiKey.trim());
        try {
          const stats = await partnerRequest<{
            imf: PartnerImfInfo;
          }>("/partners/stats");
          partnerStorage.setImf(stats.imf);
          setKey(apiKey.trim());
          setImf(stats.imf);
        } catch (err) {
          partnerStorage.clear();
          setKey(null);
          setImf(null);
          throw err;
        }
      },
      logout() {
        partnerStorage.clear();
        setKey(null);
        setImf(null);
      },
    }),
    [key, imf]
  );

  return (
    <ImfAuthContext.Provider value={value}>{children}</ImfAuthContext.Provider>
  );
}

export function useImfAuth() {
  const ctx = useContext(ImfAuthContext);
  if (!ctx) throw new Error("useImfAuth hors ImfAuthProvider");
  return ctx;
}
