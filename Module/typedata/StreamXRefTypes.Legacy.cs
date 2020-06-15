using System;
using System.Collections.Generic;

namespace StreamXRef
{
    public class ImportCounter
    {
        public string Name { get; set; }
        public int Imported { get; set; }
        public int Skipped { get; set; }
        public int Error { get; set; }
        public int Total
        {
            get
            {
                return (Imported + Skipped + Error);
            }
        }

        public ImportCounter(string name)
        {
            Name = name;
            Imported = 0;
            Skipped = 0;
            Error = 0;
        }

        public override string ToString()
        {
            return "Imported: " + Imported + ", Skipped: " + Skipped + ", Error: " + Error + ", Total: " + Total;
        }
    }

    public class ImportResults : Dictionary<String, ImportCounter>
    {
        public void AddCounter(string name)
        {
            this.Add(name, new ImportCounter(name));
        }

        public int AllImported
        {
            get
            {
                int sum = 0;
                try
                {
                    foreach (string part in this.Keys)
                    {
                        sum += this[part].Imported;
                    }
                    return (sum);
                }
                catch
                {
                    return (-1);
                }
            }
        }

        public int AllSkipped
        {
            get
            {
                int sum = 0;
                try
                {
                    foreach (string part in this.Keys)
                    {
                        sum += this[part].Skipped;
                    }
                    return (sum);
                }
                catch
                {
                    return (-1);
                }
            }
        }

        public int AllError
        {
            get
            {
                int sum = 0;
                try
                {
                    foreach (string part in this.Keys)
                    {
                        sum += this[part].Error;
                    }
                    return (sum);
                }
                catch
                {
                    return (-1);
                }
            }
        }

        public int AllTotal
        {
            get
            {
                int sum = 0;
                try
                {
                    foreach (string part in this.Keys)
                    {
                        sum += this[part].Total;
                    }
                    return (sum);
                }
                catch
                {
                    return (-1);
                }
            }
        }
    }
}
