namespace TerraPlantarum.Application.Common
{
    public class PagedResponse<T>
    {
        public required IEnumerable<T> Data { get; set; }
        public required int Page { get; set; }
        public required int PageSize { get; set; }
        public required int TotalCount { get; set; }
        public required int TotalPages { get; set; }
    }
}
