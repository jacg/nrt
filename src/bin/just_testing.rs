fn create_str_attr<T>(location: &T, name: &str, value: &str) -> hdf5::Result<()>
where
    T: std::ops::Deref<Target = hdf5::Location>,
{
    let attr = location.new_attr::<hdf5::types::VarLenUnicode>().create(name)?;
    let value: hdf5::types::VarLenUnicode = value.parse().unwrap();
    attr.write_scalar(&value)
}

fn main() -> hdf5::Result<()> {

    // suppress spamming stdout
    let _suppress_errors = hdf5::silence_errors(true);

    let file_name = "/tmp/attribute_test.h5"; // TODO generate filename
    let group_name = "the_group";
    let dataset_name = "the_dataset";

    let file = hdf5::File::create(file_name)?;
    let group: hdf5::Group = file.create_group(group_name)?;
    let dataset: hdf5::Dataset = group
        .new_dataset_builder()
        .with_data(&[1.2, 3.4])
        .create(dataset_name)?;

    let attr = dataset.new_attr::<hdf5::types::VarLenUnicode>().create("unicode_attribute")?;
    let value: hdf5::types::VarLenUnicode = "‽🚐".parse().unwrap();
    attr.write_scalar(&value)?;

    create_str_attr(&*dataset, "dataset_unicode_attribute", "‽🚐")?;
    create_str_attr(& group  , "group_unicode_attribute", "‽🚐")?;
    Ok(())
}
