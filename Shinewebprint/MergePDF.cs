using iTextSharp.text.pdf;
using iTextSharp.text;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Shinewebprint
{
    public class MergePDF
    {
        public static string MergeAllPDF(string outputPdfPath, string[] File1)
        {
            string[] fileArray = new string[File1.Length];
            for (int a = 0; a < File1.Length; a++)
            {
                fileArray[a] = File1[a].ToString();
            }

            PdfReader reader = null;
            Document sourceDocument = null;
            PdfCopy pdfCopyProvider = null;
            PdfImportedPage importedPage;
            //string outputPdfPath = @"E:\samppdf\opf\newFile.pdf";
            outputPdfPath = outputPdfPath + "GrpPDF_" + DateTime.Now.ToString("yyyyMMddHHmmssffff") + ".pdf";
            sourceDocument = new Document();
            pdfCopyProvider = new PdfCopy(sourceDocument, new System.IO.FileStream(outputPdfPath, System.IO.FileMode.Create));

            //output file Open  
            sourceDocument.Open();


            //files list wise Loop  
            for (int f = 0; f < fileArray.Length; f++)
            {
                int pages = TotalPageCount(fileArray[f]);

                reader = new PdfReader(fileArray[f]);
                //Add pages in new file  
                for (int i = 1; i <= pages; i++)
                {
                    importedPage = pdfCopyProvider.GetImportedPage(reader, i);
                    pdfCopyProvider.AddPage(importedPage);
                }
                reader.Close();
            }
            //save the output file  
            sourceDocument.Close();
            return outputPdfPath;
        }

        private static int TotalPageCount(string file)
        {
            using (StreamReader sr = new StreamReader(System.IO.File.OpenRead(file)))
            {
                Regex regex = new Regex(@"/Type\s*/Page[^s]");
                MatchCollection matches = regex.Matches(sr.ReadToEnd());

                return matches.Count;
            }
        }
    }
}
