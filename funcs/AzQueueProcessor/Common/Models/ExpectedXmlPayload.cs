using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Xml.Serialization;

namespace AzQueueProcessor.Common.Models
{
    [XmlRoot(ElementName = "catalog")]
    public class Catalog
    {
        [XmlElement(ElementName = "book")]
        public List<Book> Books { get; set; } = new List<Book>();

        public Book this[string id]
        {
            get { return Books.FirstOrDefault(s => string.Equals(s.Id, id, StringComparison.OrdinalIgnoreCase)); }
        }
    }

    public class Book
    {
        [XmlAttribute(AttributeName = "id")]
        public string Id { get; set; }

        [XmlElement(ElementName = "author")]
        public string Author { get; set; }

        [XmlElement(ElementName = "title")]
        public string Title { get; set; }

        [XmlElement(ElementName = "genre")]
        public string Genre { get; set; }

        [XmlElement(ElementName = "price")]
        public decimal? Price { get; set; }

        [XmlElement(ElementName = "publish_date")]
        public string PublishDate { get; set; }

        [XmlElement(ElementName = "description")]
        public string Description { get; set; }
    }
}
