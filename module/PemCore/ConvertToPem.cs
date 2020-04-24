using System;
using System.Management.Automation;
using System.Security.Cryptography;
using System.Text;
using System.IO;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.OpenSsl;
using Org.BouncyCastle.Crypto.Parameters;
using Org.BouncyCastle.Security;
using Org.BouncyCastle.Crypto.Generators;
using Org.BouncyCastle.Math;
using System.Management.Automation.Runspaces;

namespace PemCore
{

    [Cmdlet(VerbsData.ConvertTo, "Pem")]
    public class ConvertToPem : Cmdlet
    {
        private string _base64Value = "nvBase64";
        [Parameter(Mandatory = true)]
        public string Base64
        {
            get { return _base64Value; }
            set { _base64Value = value; }
        }

        protected override void ProcessRecord()
        {
            WriteObject("Base64 " + this.Base64);

            try
            {

                RSAKey result = new RSAKey();
                IAsymmetricCipherKeyPairGenerator gen;
                KeyGenerationParameters param;
                gen = new RsaKeyPairGenerator();
                param = new RsaKeyGenerationParameters(
                    BigInteger.ValueOf(3L),
                    new SecureRandom(),
                    2048,
                    80
                );
                gen.Init(param);
                AsymmetricCipherKeyPair pair = gen.GenerateKeyPair();
                using (TextWriter textWriter = new StringWriter())
                {
                    PemWriter wr = new PemWriter(textWriter);
                    wr.WriteObject(pair.Private);
                    wr.Writer.Flush();

                    result.PrivatePEM = textWriter.ToString();
                }

                using (TextWriter textWriter = new StringWriter())
                {
                    PemWriter wr = new PemWriter(textWriter);
                    wr.WriteObject(pair.Public);
                    wr.Writer.Flush();

                    result.PublicPEM = textWriter.ToString();
                }

                using (StringReader sr = new StringReader(result.PublicPEM))
                {
                    PemReader reader = new PemReader(sr);
                    RsaKeyParameters r = (RsaKeyParameters)reader.ReadObject();
                    byte[] sshrsa_bytes = Encoding.Default.GetBytes("ssh-rsa");
                    byte[] n = r.Modulus.ToByteArray();
                    byte[] e = r.Exponent.ToByteArray();


                    string buffer64;
                    using (MemoryStream ms = new MemoryStream())
                    {
                        ms.Write(ToBytes(sshrsa_bytes.Length), 0, 4);
                        ms.Write(sshrsa_bytes, 0, sshrsa_bytes.Length);
                        ms.Write(ToBytes(e.Length), 0, 4);
                        ms.Write(e, 0, e.Length);
                        ms.Write(ToBytes(n.Length + 1), 0, 4); //Remove the +1 if not Emulating Putty Gen
                        ms.Write(new byte[] { 0 }, 0, 1); //Add a 0 to Emulate PuttyGen
                        ms.Write(n, 0, n.Length);
                        ms.Flush();
                        buffer64 = Convert.ToBase64String(ms.ToArray());
                    }

                    result.PublicSSH = string.Format("ssh-rsa {0} generated-key", buffer64);
                }

                WriteObject(result);

            }
            catch (Org.BouncyCastle.Crypto.CryptoException ex)
            {
                throw ex;
            }
        }

        private static byte[] ToBytes(int i)
        {
            byte[] bts = BitConverter.GetBytes(i);
            if (BitConverter.IsLittleEndian)
            {
                Array.Reverse(bts);
            }
            return bts;
        }
    }
}