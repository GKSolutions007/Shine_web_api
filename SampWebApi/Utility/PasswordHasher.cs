using System;
using System.Security.Cryptography;
using SampWebApi.DALHelper;

namespace SampWebApi.Utility
{
    /// <summary>
    /// One-way password hashing for tblUsers.Password (point 9).
    ///
    /// Format stored in the existing nvarchar column:
    ///     PBKDF2$SHA256$&lt;iterations&gt;$&lt;base64 salt&gt;$&lt;base64 hash&gt;
    /// - random 16-byte salt per password, 32-byte PBKDF2-HMAC-SHA256 hash
    /// - the iteration count is stored with the hash, so it can be raised later without
    ///   breaking existing hashes (old hashes are re-hashed on the next successful login)
    ///
    /// Legacy values (clsEncryptDecrypt ciphertext, reversible with the key in source) are still
    /// accepted by Verify so existing users can log in; the caller then replaces them with a hash.
    /// </summary>
    public static class PasswordHasher
    {
        private const string Prefix = "PBKDF2$SHA256$";
        public const int CurrentIterations = 120000;
        private const int SaltBytes = 16;
        private const int HashBytes = 32;

        /// <summary>Hashes a password for storage. Never returns the password itself.</summary>
        public static string Hash(string password)
        {
            if (password == null) throw new ArgumentNullException(nameof(password));
            byte[] salt = new byte[SaltBytes];
            using (var rng = RandomNumberGenerator.Create())
                rng.GetBytes(salt);
            byte[] hash = Derive(password, salt, CurrentIterations, HashBytes);
            return Prefix + CurrentIterations + "$" + Convert.ToBase64String(salt) + "$" + Convert.ToBase64String(hash);
        }

        /// <summary>True if the stored value is in the PBKDF2 format (not legacy ciphertext).</summary>
        public static bool IsHashed(string stored)
        {
            return !string.IsNullOrEmpty(stored) && stored.StartsWith(Prefix, StringComparison.Ordinal);
        }

        /// <summary>
        /// Checks a password against a stored value.
        /// needsRehash is true when the password is correct but the stored value is legacy
        /// ciphertext or uses fewer iterations than CurrentIterations: store Hash(password) then.
        /// </summary>
        public static bool Verify(string password, string stored, out bool needsRehash)
        {
            needsRehash = false;
            if (password == null || string.IsNullOrEmpty(stored)) return false;

            if (IsHashed(stored))
            {
                string[] parts = stored.Split('$');   // PBKDF2, SHA256, iterations, salt, hash
                int iterations;
                if (parts.Length != 5 || !int.TryParse(parts[2], out iterations) || iterations < 1) return false;
                byte[] salt, expected;
                try
                {
                    salt = Convert.FromBase64String(parts[3]);
                    expected = Convert.FromBase64String(parts[4]);
                }
                catch (FormatException) { return false; }
                if (salt.Length == 0 || expected.Length == 0) return false;

                byte[] actual = Derive(password, salt, iterations, expected.Length);
                bool ok = FixedTimeEquals(actual, expected);
                needsRehash = ok && iterations < CurrentIterations;
                return ok;
            }

            // Legacy: the column held clsEncryptDecrypt.Encrypt(password), which is deterministic.
            bool legacyOk;
            try { legacyOk = FixedTimeEquals(clsEncryptDecrypt.Encrypt(password), stored); }
            catch (CryptographicException) { legacyOk = false; }
            needsRehash = legacyOk;
            return legacyOk;
        }

        private static byte[] Derive(string password, byte[] salt, int iterations, int length)
        {
            using (var kdf = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256))
                return kdf.GetBytes(length);
        }

        // Constant-time comparison so response time does not reveal how many bytes matched.
        private static bool FixedTimeEquals(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length) return false;
            int diff = 0;
            for (int i = 0; i < a.Length; i++) diff |= a[i] ^ b[i];
            return diff == 0;
        }

        private static bool FixedTimeEquals(string a, string b)
        {
            if (a == null || b == null) return false;
            return FixedTimeEquals(System.Text.Encoding.UTF8.GetBytes(a), System.Text.Encoding.UTF8.GetBytes(b));
        }
    }
}
